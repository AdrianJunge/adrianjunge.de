---
description: Java Strings are immutable, interned, optimized, and surprisingly easy to misunderstand when secrets are involved. This post digs into String pooling, reflection, Base64 copies, library APIs, and why heap dumps are bad news for secrets.
categories:
    - Java
    - JVM Internals
    - Security Research
    - Memory
published: "2026-05-27"
---
# The Tiny Problem With Strings

Imagine some Java service where you type in `"some secret"`, its getting passed through a few libraries, authenticate somewhere, and you move on with your life. Then you remember that the Java `String` class is immutable, often shared, sometimes interned, and not something you can reliably scrub from memory afterwards. So the core question is simple:

**If a secret becomes a `java.lang.String`, can we clean it up well enough to survive a memory dump?**

Short answer: not really.

Longer answer: Java is doing exactly what it is designed to do, but that design is very inconvenient for secret handling.

# Threat Model

Assume an attacker can obtain heap dumps, process snapshots, or comparable memory disclosures. In Java applications this can happen in a variety of different ways:

- An exposed [Spring Boot Actuator `heapdump` endpoint](https://docs.spring.io/spring-boot/reference/actuator/endpoints.html) can return a heap dump file.
- Unsafe JNI usage or native libraries can introduce memory corruption bugs.
- Native dependencies can be affected by their own memory-safety bugs, for example something similar to [Heartbleed](https://www.heartbleed.com/).
- Operators, debugging tooling, crash dumps, and snapshots can all create copies of process memory.

If an attacker can continuously read live process memory, this becomes impossible to solve in-process because credentials must exist in memory while authentication is happening. Sending password-equivalent material, such as a reusable client-side hash, would only lead to more problems. So the more realistic model is that an attacker obtains one or a few dumps.

# What Java Promises

The Java API promise is straightforward:

- [`java.lang.String`](https://docs.oracle.com/en/java/javase/26/docs/api/java.base/java/lang/String.html) is final.
- [`String` values cannot be changed after creation and thus are immutable](https://docs.oracle.com/en/java/javase/26/docs/api/java.base/java/lang/String.html).
- [String literals are `String` instances](https://docs.oracle.com/javase/specs/jls/se26/html/jls-3.html#jls-3.10.5).
- [String literals and constant-expression strings are interned](https://docs.oracle.com/javase/specs/jls/se26/html/jls-3.html#jls-3.10.5).
- [`String.intern()` returns the canonical pooled instance](https://docs.oracle.com/en/java/javase/26/docs/api/java.base/java/lang/String.html#intern()) for equal string contents.

The string pool is the JVM's table of canonical `String` instances. That does not mean pooled strings live in some magic non-heap place. On modern HotSpot JVM they are still normal heap objects, while the pool keeps track of the canonical references. Interning is the process of looking up a string in that pool and using the pooled object for equal text. If no equal string is present, the string can be added to the pool. If it is already present, the existing pooled object is returned. String literals and constant-expression strings are interned automatically, while `intern()` lets you ask for that canonical pooled object explicitly.

The following [DigitalOcean Java String Pool diagram](https://www.digitalocean.com/community/tutorials/what-is-java-string-pool) gives a compact visual example:

![Java String Pool diagram showing two string literals pointing to one pooled object while new String creates a separate object.](blog/posts/java-strings/java-string-pool.png "Java String Pool diagram")

This represents exactly what we can observe by executing the following code:

```java
String literal = "teststring";
String object = new String("teststring");

System.out.println(literal == object);          // false
System.out.println(literal == object.intern()); // true
```

The first comparison is false because `new String(...)` creates a distinct `String` object on the heap. The second comparison is true because `intern()` returns the canonical pooled instance for the same contents. In `new String("teststring")`, the `"teststring"` argument is a string literal, and the literal is interned by the language. The result of `new String(...)` is the separate object, and it is not automatically added to the pool.

# The String Layout

On OpenJDK/HotSpot `26.0.1`, [`String` uses compact strings internally](https://openjdk.org/jeps/254). The [`String.java` implementation](https://github.com/openjdk/jdk26u/blob/jdk-26.0.1-ga/src/java.base/share/classes/java/lang/String.java#L177-L260) shows the internal `private final byte[] value` byte array, the `private final byte coder` field with `LATIN1` / `UTF16` values, and the `COMPACT_STRINGS` switch. Latin-1 strings use one byte per character. Strings requiring UTF-16 use two bytes per character. However, this implementation detail matters because the [`public String(String original)` constructor](https://github.com/openjdk/jdk26u/blob/jdk-26.0.1-ga/src/java.base/share/classes/java/lang/String.java#L295-L300) copies the reference `value` to `original.value`. In other words:

```java
String literal = "somepassword";
String object = new String("somepassword");
```

`literal` and `object` are different `String` objects, but they can share the same `byte[]` internally. That detail is where things become cursed.

# Mutating The Immutable

Now let's take a closer look at the tempting idea: just erase the memory where the string lives and clean up the service afterwards. Modern Java does not let normal reflection access `String.value` directly because [`AccessibleObject.setAccessible(true)` can only suppress access checks when the declaring package is open to the caller's module](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/reflect/AccessibleObject.html#setAccessible(boolean)). To run the experiment the `java.lang` package has to be opened:

```bash
java --add-opens java.base/java.lang=ALL-UNNAMED StringReflectionTest.java
```

Now for the bad idea:

```java
import java.lang.reflect.Field;

class StringReflectionTest {
   public static void main(String[] args) throws Exception {
      String newString1 = new String("somepassword");
      String newString2 = new String("somepassword");
      String literal = "somepassword";
      System.out.println("Original literal: " + literal);                  // somepassword
      System.out.println("Original String 1: " + newString1);              // somepassword
      System.out.println("Original String 2: " + newString2);              // somepassword
      System.out.println(literal == newString1);                           // false
      System.out.println(literal == literal.intern());                     // true
      System.out.println(newString1 == newString1.intern());               // false
      System.out.println(literal == newString1.intern());                  // true
      System.out.println(literal.intern() == newString1.intern());         // true
      System.out.println(literal.intern() == newString2.intern());         // true

      Field privateField = String.class.getDeclaredField("value");
      privateField.setAccessible(true);

      byte[] value = (byte[]) privateField.get(newString1);
      for (int i = 0; i < value.length; i++) {
         value[i] = 0;
      }

      System.out.println("Modified literal: " + literal);                  // NUL characters
      System.out.println("Modified String 1: " + newString1);              // NUL characters
      System.out.println("Modified String 2: " + newString2);              // NUL characters

      String newLiteral = "somepassword";
      String newLiteralConcat = "some" + "password";
      String newString3 = new String("somepassword");
      String newString4 = new String("somepassword");
      String newStringConcat = new String("some" + "password");
      System.out.println("New literal: " + newLiteral);                    // NUL characters
      System.out.println("New literal concat: " + newLiteralConcat);       // NUL characters
      System.out.println("New string 3: " + newString3);                   // NUL characters
      System.out.println("New string 4: " + newString4);                   // NUL characters
      System.out.println("New string concat: " + newStringConcat);         // NUL characters
   }
}
```

Those final print statements contain **NUL characters**. The strings still have length 12, but the internal `byte[]` array have been overwritten with zeroes. That does not mean every `String` with the same text shares the same `byte[]` array. For example, the follwoing can have independent internal arrays:

```java
String fromChars = new String(new char[] {
   's', 'o', 'm', 'e', 'p', 'a', 's', 's', 'w', 'o', 'r', 'd'
});
String fromBytes = new String("somepassword".getBytes());

String runtimePart = "password";
String runtimeConcat = "some" + runtimePart;
```

Those strings do not share the literal `byte[]` array. The public [`String(char[])` constructor](https://github.com/openjdk/jdk26u/blob/jdk-26.0.1-ga/src/java.base/share/classes/java/lang/String.java#L314-L343) copies character data, the public [`String(byte[])` constructor](https://github.com/openjdk/jdk26u/blob/jdk-26.0.1-ga/src/java.base/share/classes/java/lang/String.java#L1673-L1698) decodes bytes into a new string, and runtime concatenation is not the same as passing an existing `String` object into `new String(String)`. So the weird mutation behavior is real, but the exact sharing is an implementation detail and depends on how the `String` was created.

# Why Reflection Is Not Cleanup

The reflection trick looks tempting if your goal is to erase secrets. But it is also a trap. It depends on private internals. It needs the `--add-opens` hack and it can corrupt literals and unrelated code that shares the same internal storage. Using this trick might break authentication, maps, caches, logs, protocol code, and anything else that assumes strings are immutable.

Moreover, as we saw in the `char[]` array example after the reflection, not every equal string points to the same `byte[]`. Strings built from request bytes, character arrays, runtime concatenation, parsers, encoders, or library code can have their own backing arrays. Zeroing one internal array only affects strings that happen to use that exact array. Thus finding and scrubbing every representation might be very tedious, doesn't scale at all and likely break on dependency updates.

# The Library Problem

Another issue is that our credential-handling service can still hit awkward API boundaries.

First, a dependency may simply require a `String`. For example, JDBC's [`DriverManager.getConnection(String url, String user, String password)` overload](https://docs.oracle.com/en/java/javase/26/docs/api/java.sql/java/sql/DriverManager.html#getConnection(java.lang.String,java.lang.String,java.lang.String)) takes the password as a `String`. If your own code started with a mutable buffer, that advantage disappears at such an API boundary.

Second, any encryption or encoding happening inside a library can create its own immutable copies. So even when a library allows you to pass mutable `byte[]` arrays, there still might be string occurrences in memory with sensitive data. A classic example is code like this:

```java
Base64.getEncoder().encodeToString(plaintext)
```

[Java's `Base64.Encoder.encodeToString(byte[])`](https://docs.oracle.com/en/java/javase/26/docs/api/java.base/java/util/Base64.Encoder.html#encodeToString(byte%5B%5D)) returns a `String` containing the Base64-encoded bytes. As `Base64` is an easily reversible encoding, the `Base64` string is sensitive too. Even if your own code starts with a mutable `byte[]`, a dependency can still create immutable sensitive `String` copies internally.

# What About The Garbage Collector?

The garbage collector is not a secret-erasure mechanism. An object becoming unreachable does not mean it is collected immediately. Moreover collection does not guarantee that the old bytes are overwritten with zeroes. Depending on the collector and heap state, stale data could remain in heap regions, copied regions, survivor spaces, old generations, or heap dumps until that memory is reused or the process exits.

String literals are especially long-lived in typical services. A literal like `"somepassword"` is part of the class that contains it, and [Java interns string literals](https://docs.oracle.com/javase/specs/jls/se26/html/jls-3.html#jls-3.10.5). The class can only be unloaded when its defining class loader can be reclaimed, as described by the [JLS class unloading rules](https://docs.oracle.com/javase/specs/jls/se26/html/jls-12.html#jls-12.7). In a normal long-running application, the main application class loader is usually alive until the process exits. So literals from those classes often stay reachable for the whole process lifetime. Other interned strings can become collectible when nothing references them anymore, but relying on that for secret cleanup is still not a useful defense in this threat model.

# What Actually Helps

There is no magic in-process fix when assuming an attacker can read your memory. Still, there are practical mitigations:

- Avoid `String` for secrets where APIs allow `char[]`, `byte[]`, or dedicated secret wrappers.
- Overwrite mutable secret buffers as soon as they are no longer needed.
- Disable and protect memory dump endpoints.
- Treat memory dumps, crash dumps, logs, and snapshots as sensitive artifacts.
- Avoid logging secrets and encoded variants of secrets.
- Keep native dependencies patched.
- Restart short-lived worker processes if you need to reduce secret lifetime in memory.
- Prefer designs where the process never receives long-lived user secrets if that is architecturally possible.

[Secure string wrappers like `GuardedString`](https://docs.oracle.com/cd/E23943_01/apirefs.1111/e24834/org/identityconnectors/common/security/package-summary.html) can make secret handling safer in code you control, because they avoid keeping the secret as a plain `String` all the time. But once you pass the secret to a library that asks for a normal `String`, that library can still create ordinary string copies.

# Conclusion

Java strings are not broken. They are optimized for being immutable, shareable, and efficient. But you have to pay attention when using them for secrets. The funny part is that you can mutate a `String` anyway if you kick the module system open hard enough. The less funny part is that this leads to fragile code instead of a secure cleanup strategy. If a secret reaches a `String`, assume it will remain in the memory and may have multiple copies, probably even encoded ones with reversible encodings. If an attacker can obtain heap dumps or process memory, the real defense is preventing that access in the first place.

The JVM will not save your password from a memory dump - it is too busy making `"hello"` fast.
