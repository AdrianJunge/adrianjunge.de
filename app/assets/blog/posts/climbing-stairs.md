---
description: LeetCode's Climbing Stairs problem looks like a tiny dynamic-programming warmup, but it is also a neat meeting point between Fibonacci numbers, binomial coefficients, Pascal's triangle, and tilings.
categories:
    - LeetCode
    - Algorithms
    - Dynamic Programming
    - Combinatorics
published: "2026-07-05"
---

# Climbing Stairs from Two Angles

The [Climbing Stairs](https://leetcode.com/problems/climbing-stairs/) problem on [LeetCode](https://leetcode.com/) is one of those algorithm questions that looks almost too small. There are `n` stairs, each move can cover either one or two stairs, and the task is to count how many distinct ordered move sequences can reach the top. For example, for `n = 5`, this is a valid climb:

```text
1 + 2 + 2
```

But you can also climb like this:

```text
2 + 1 + 2
```

There are actually two completely different approaches to solve this task. One is the [Fibonacci](https://en.wikipedia.org/wiki/Fibonacci_sequence) recurrence. The other is a direct [combinatorial](https://en.wikipedia.org/wiki/Combinatorics) count. I solved this challenge some time ago in the **combinatorial** way. Later I discussed the same challenge with a friend of mine, who solved it with the **Fibonacci** approach. Both of us were a bit surprised that two approaches that felt so different on the surface produced exactly the same result. For me, that discussion made the challenge even more interesting, because it showed how completely different perspectives can lead to the same answer.

# The Mental Model: Tiny Tiles

A useful way to look at the problem is to turn the stairs into a board of length `n`. The task then becomes: how many ways can a board of length `n` be tiled with pieces of length `1` and `2`? For `n = 5`, the answer is `8`, where `k` is the number of tiles of length `2`:

![All eight ways to climb five stairs, grouped by how many two-step moves they use.](blog/posts/climbing-stairs/tilings-n5.svg "All tilings for n = 5")

The two different approaches are already visible in the same drawing:
- **Fibonacci** counts the rows by how they end
- **Combinatorics** counts the rows by how many `2`-tiles they contain

# Two Different Approaches - Same Solution

`W(n)` is the number of ordered sequences made only from `1` and `2` whose sum is exactly `n`. That is exactly the value the [Climbing Stairs](https://leetcode.com/problems/climbing-stairs/) problem asks for:

<div>
    \[
    W(n)
    =
    \left|
    \left\{
    (a_1,\dots,a_m)
    \mid
    m \ge 0,\ a_i \in \{1,2\},\ \sum_{i=1}^{m} a_i = n
    \right\}
    \right|
    \]
</div>

For the recurrence, the value of step `0` means that a path has already reached the target and has produced one complete valid sequence. Negative stair counts are impossible, so they add nothing to the calculation:

<div>
    \[
    W(0) = 1,
    \qquad
    W(n) = 0 \text{ for } n < 0
    \]
</div>

The **Fibonacci** numbers are defined as follows:

<div>
    \[
    F_0 = 0,
    \qquad
    F_1 = 1,
    \qquad
    F_m = F_{m-1} + F_{m-2} \text{ for } m \ge 2
    \]
</div>

The **Fibonacci** view groups climbs by the final move. Every valid climb to `n` must end in exactly one of these two ways:
- a valid climb to `n - 1`, then one final `1`-step
- a valid climb to `n - 2`, then one final `2`-step

These two groups do not overlap, because a sequence cannot end in both `1` and `2`. They also cover every valid climb, because the final move has to be either `1` or `2`. Therefore, for `n >= 1`:

<div>
    \[
    W(n) = W(n - 1) + W(n - 2)
    \]
</div>

Now compare that with the **Fibonacci** recurrence. The recurrence has the same shape, but the indexing is shifted by one:

<div>
    \[
    W(0) = 1 = F_1,
    \qquad
    W(1) = 1 = F_2
    \]
</div>

After those two starting values, both sequences follow the same recurrence:

<div>
    \[
    W(n) = W(n - 1) + W(n - 2),
    \qquad
    F_{n+1} = F_n + F_{n-1}
    \]
</div>

So, by induction:

<div>
    \[
    W(n) = F_{n+1}
    \]
</div>

The **combinatorics** view starts from the same `W(n)`, but groups the same set of climbs differently. Instead of looking at the final move, fix the number of `2`-step moves. Suppose a sequence uses exactly `k` two-step moves. Those moves cover `2k` stairs, so the remaining stairs must be covered by `n - 2k` one-step moves. That explains the upper bound on `k`: the sequence must not overshoot the staircase.

<div>
    \[
    n - 2k \ge 0
    \quad\Longleftrightarrow\quad
    k \le \left\lfloor \frac{n}{2} \right\rfloor
    \]
</div>

For a fixed valid `k`, the sequence contains `k` moves of size `2` and `n - 2k` moves of size `1`. So the total number of moves is:

<div>
    \[
    k + (n - 2k) = n - k
    \]
</div>

Now the only question is where the `k` two-step moves are placed among those `n - k` total move positions. Choosing those positions gives:

<div>
    \[
    \binom{n-k}{k}
    \]
</div>

Finally, each valid climb has exactly one value of `k`, so the groups for different `k` do not overlap. Summing over all possible `k` values gives the **combinatorial** formula:

<div>
    \[
    W(n) =
    \sum_{k=0}^{\lfloor n/2 \rfloor}
    \binom{n-k}{k}
    \]
</div>

Putting both views together gives:

<div>
    \[
    W(n) = F_{n+1}
    =
    \sum_{k=0}^{\lfloor n/2 \rfloor}
    \binom{n-k}{k}
    \]
</div>

So the **Fibonacci** side and the **combinatorial** side are two different descriptions of the same solution `W(n)`. They count the same set of climbs, just grouped in different ways.

# Pascal's Triangle As A Sanity Check

[Pascal's triangle](https://en.wikipedia.org/wiki/Pascal%27s_triangle) is useful here as a visual proof because it stores **binomial coefficients**. The **combinatorial formula** asks for **coefficients** along this pattern:

<div>
    \[
    \binom{n}{0},
    \binom{n-1}{1},
    \binom{n-2}{2},
    \binom{n-3}{3},
    \dots
    \]
</div>

So for `n = 5`, we look for:

<div>
    \[
    \binom{5}{0},
    \binom{4}{1},
    \binom{3}{2}
    \]
</div>

In **Pascal's triangle**, those values sit on one shallow diagonal:

![Pascal's triangle shallow diagonal C(5,0), C(4,1), C(3,2) summing to F6.](blog/posts/climbing-stairs/pascal-diagonal.svg "Pascal triangle shallow diagonal")

The highlighted diagonal adds up to:

<div>
    \[
    1 + 4 + 3 = 8 = F_6 = W(5)
    \]
</div>

So the picture shows the same result again: there are `8` ways to climb `5` stairs. For `n = 6`, the same diagonal pattern gives:

<div>
    \[
    \binom{6}{0}
    +
    \binom{5}{1}
    +
    \binom{4}{2}
    +
    \binom{3}{3}
    =
    1 + 5 + 6 + 1
    =
    13 = F_7 = W(6)
    \]
</div>

So the shallow diagonal sum for `n` is:

<div>
    \[
    W(n)
    =
    F_{n+1}
    \]
</div>

This diagonal pattern appears because **Pascal's triangle** itself is built by addition:

```text
upper-left + upper-right
          |
       current
```

When the correct shallow diagonals are summed, that local addition creates the same shape as the **Fibonacci** recurrence:

<div>
    \[
    \text{current diagonal}
    =
    \text{previous diagonal}
    +
    \text{diagonal before that}
    \]
</div>

# Implementation Examples

The examples below use the mathematical base case `W(0) = 1`, so they also behave sensibly for `n = 0`. [LeetCode](https://leetcode.com/) itself uses `n >= 1`, so this does not change the accepted answers for the actual challenge.

The complexity formulas use the usual LeetCode model where arithmetic on the returned integers is treated as constant time:

<div>
    \[
    \text{one integer arithmetic operation} = \Theta(1)
    \]
</div>

If `n` is allowed to grow arbitrarily large, the returned value itself has a linear number of bits:

<div>
    \[
    \operatorname{bits}(F_{n+1}) = \Theta(n)
    \]
</div>

So exact big-integer analysis would add another layer. For comparing the implementation shapes below, the standard model is the useful one.

## Fibonacci Implementations

The **Fibonacci** family is all about this recurrence:

<div>
    \[
    W(n) = W(n - 1) + W(n - 2)
    \]
</div>

The variants below differ only in how they compute it.

### Fibonacci: Plain Recursion

The most direct implementation is also the worst practical one:

```python
class Solution:
    def climbStairs(self, n: int) -> int:
        if n <= 1:
            return 1

        return self.climbStairs(n - 1) + self.climbStairs(n - 2)
```

This is conceptually nice and computationally terrible. It recomputes the same values again and again. For example, `climbStairs(6)` calls `climbStairs(5)` and `climbStairs(4)`. But `climbStairs(5)` also calls `climbStairs(4)`. Then each of those calls repeats the same pattern below it. The recursion tree grows exponentially.

The runtime follows essentially the same branching pattern as the **Fibonacci** recurrence:

<div>
    \[
    T(n) = T(n-1) + T(n-2) + \Theta(1)
    \]
</div>

So the tighter bound is:

<div>
    \[
    T(n) = \Theta(F_n) = \Theta(\varphi^n)
    \]
</div>

where:

<div>
    \[
    \varphi = \frac{1 + \sqrt{5}}{2}
    \]
</div>

In this context, the symbol φ represents the golden ratio, which is approximately `1.618`. It appears here because **Fibonacci** numbers grow roughly like powers of the golden ratio.

The recursion stack can be as deep as `n`:

<div>
    \[
    S(n) = \Theta(n)
    \]
</div>

### Fibonacci: Memoized Recursion

Memoization keeps the recursive shape but stores already-computed values:

```python
from functools import cache

class Solution:
    @cache
    def climbStairs(self, n: int) -> int:
        if n <= 1:
            return 1

        return self.climbStairs(n - 1) + self.climbStairs(n - 2)
```

Now every `n` is computed once. There are only `n + 1` possible states from `0` to `n`:

<div>
    \[
    T(n) = \Theta(n)
    \]
</div>

The cache stores `n + 1` values, and the recursive call stack can still have depth `n`:

<div>
    \[
    S(n) = \Theta(n)
    \]
</div>

This is still clearly a **Fibonacci** solution. The only difference from the brute-force version is that repeated subproblems are cached.

### Fibonacci: Bottom-Up DP

The bottom-up version removes recursion and fills the values in order:

```python
class Solution:
    def climbStairs(self, n: int) -> int:
        if n <= 1:
            return 1

        dp = [0] * (n + 1)
        dp[0] = 1
        dp[1] = 1

        for i in range(2, n + 1):
            dp[i] = dp[i - 1] + dp[i - 2]

        return dp[n]
```

This is the standard dynamic-programming version. The loop fills each state once:

<div>
    \[
    T(n) = \Theta(n)
    \]
</div>

The array stores one value per state:

<div>
    \[
    S(n) = \Theta(n)
    \]
</div>

It is explicit and easy to debug. It also makes the dependency structure obvious: every cell only depends on the previous two cells.

### Fibonacci: Space-Optimized DP

Since `dp[i]` only needs `dp[i - 1]` and `dp[i - 2]`, we do not need the full array:

```python
class Solution:
    def climbStairs(self, n: int) -> int:
        prev2, prev1 = 1, 1

        for _ in range(2, n + 1):
            prev2, prev1 = prev1, prev1 + prev2

        return prev1
```

The loop still advances through the states one by one:

<div>
    \[
    T(n) = \Theta(n)
    \]
</div>

But it stores only the previous two values:

<div>
    \[
    S(n) = \Theta(1)
    \]
</div>

### Fibonacci: Matrix Exponentiation

For [LeetCode](https://leetcode.com/)'s constraints, the linear DP version is already more than enough. But because this is **Fibonacci**, the usual **Fibonacci** machinery also applies. Matrix exponentiation computes **Fibonacci** numbers in logarithmic time:

<div>
    \[
    \begin{bmatrix}
    F_{m+1} & F_m \\
    F_m & F_{m-1}
    \end{bmatrix}
    =
    \begin{bmatrix}
    1 & 1 \\
    1 & 0
    \end{bmatrix}^m,
    \qquad m \ge 1
    \]
</div>

For this problem, the answer is:

<div>
    \[
    W(n) = F_{n+1}
    \]
</div>

So we can compute it with fast exponentiation:

```python
class Solution:
    def climbStairs(self, n: int) -> int:
        def multiply(a, b):
            return [
                [
                    a[0][0] * b[0][0] + a[0][1] * b[1][0],
                    a[0][0] * b[0][1] + a[0][1] * b[1][1],
                ],
                [
                    a[1][0] * b[0][0] + a[1][1] * b[1][0],
                    a[1][0] * b[0][1] + a[1][1] * b[1][1],
                ],
            ]

        def matrix_power(matrix, power):
            result = [[1, 0], [0, 1]]

            while power:
                if power & 1:
                    result = multiply(result, matrix)
                matrix = multiply(matrix, matrix)
                power >>= 1

            return result

        matrix = matrix_power([[1, 1], [1, 0]], n)
        return matrix[0][0]
```

Binary exponentiation performs a logarithmic number of matrix multiplications. Since the matrix size never changes, each matrix multiplication has constant cost under the standard model:

<div>
    \[
    T(n) = \Theta(\log n)
    \]
</div>

The iterative implementation stores only a constant number of fixed-size matrices:

<div>
    \[
    S(n) = \Theta(1)
    \]
</div>

### Fibonacci: Binet's Formula

[Binet's formula](https://mathworld.wolfram.com/BinetsFormula.html) is a closed-form expression for Fibonacci numbers:

<div>
    \[
    F_m =
    \frac{\varphi^m - \psi^m}{\sqrt{5}}
    \]
</div>

where:

<div>
    \[
    \varphi = \frac{1 + \sqrt{5}}{2},
    \qquad
    \psi = \frac{1 - \sqrt{5}}{2}
    \]
</div>

So:

```python
from math import sqrt

class Solution:
    def climbStairs(self, n: int) -> int:
        phi = (1 + sqrt(5)) / 2
        psi = (1 - sqrt(5)) / 2

        return round((phi ** (n + 1) - psi ** (n + 1)) / sqrt(5))
```

Under the usual fixed-precision floating-point model, this calculation takes constant time and constant space:

<div>
    \[
    T(n) = \Theta(1),
    \qquad
    S(n) = \Theta(1)
    \]
</div>

However, the result has to be rounded back to an integer, and floating-point arithmetic is not exact. That is fine for small [LeetCode](https://leetcode.com/) inputs, but for a programming solution I would still prefer the integer DP version.

## Combinatorics Implementations

The **combinatorics** family evaluates the direct counting formula:

<div>
    \[
    W(n) =
    \sum_{k=0}^{\lfloor n/2 \rfloor}
    \binom{n-k}{k}
    \]
</div>

Instead of computing `W(n - 1)` and `W(n - 2)`, it loops over the possible number of two-step moves.

### Combinatorics: Naive Factorials

A first implementation might compute binomial coefficients manually:

```python
class Solution:
    def factorial(self, n: int) -> int:
        if n <= 1:
            return 1
        return n * self.factorial(n - 1)

    def choose(self, n: int, k: int) -> int:
        return self.factorial(n) // (self.factorial(n - k) * self.factorial(k))

    def climbStairs(self, n: int) -> int:
        total = 0

        for k in range(n // 2 + 1):
            total += self.choose(n - k, k)

        return total
```

This is mathematically clear, but it is not a great implementation. It recomputes factorials for every `k`, and the recursive factorial calls add avoidable overhead. For each `k`, this version computes three factorials from scratch:

<div>
    \[
    (n-k)!,
    \qquad
    (n-2k)!,
    \qquad
    k!
    \]
</div>

Under the standard arithmetic model, the total work is:

<div>
    \[
    T(n)
    =
    \Theta\!\left(
    \sum_{k=0}^{\lfloor n/2 \rfloor}
    \bigl((n-k) + (n-2k) + k\bigr)
    \right)
    =
    \Theta(n^2)
    \]
</div>

The deepest recursive factorial call has depth at most `n`:

<div>
    \[
    S(n) = \Theta(n)
    \]
</div>

### Combinatorics: Built-In `math.comb`

The clean Python version uses `math.comb`:

```python
from math import comb

class Solution:
    def climbStairs(self, n: int) -> int:
        return sum(comb(n - k, k) for k in range(n // 2 + 1))
```

For normal [LeetCode](https://leetcode.com/) constraints this is perfectly fine. The loop has one term for each possible value of `k`:

<div>
    \[
    \left\lfloor \frac{n}{2} \right\rfloor + 1 = \Theta(n)
    \]
</div>

If `math.comb` is treated as a primitive operation, the loop complexity is:

<div>
    \[
    T(n) = \Theta(n),
    \qquad
    S(n) = \Theta(1)
    \]
</div>

The exact runtime of `math.comb` itself depends on the Python implementation and the size of the integers involved.

### Combinatorics: Multiplicative Binomial Coefficients

If you do not want to rely on `math.comb`, compute binomial coefficients multiplicatively instead of repeatedly building factorials:

```python
class Solution:
    def choose(self, n: int, k: int) -> int:
        k = min(k, n - k)
        result = 1

        for i in range(1, k + 1):
            result = result * (n - k + i) // i

        return result

    def climbStairs(self, n: int) -> int:
        return sum(self.choose(n - k, k) for k in range(n // 2 + 1))
```

This keeps everything integer-exact and avoids recomputing three factorials per term. For each term, `choose(n - k, k)` loops:

<div>
    \[
    \min(k, n - 2k)
    \]
</div>

times. So the total work is:

<div>
    \[
    T(n)
    =
    \Theta\!\left(
    \sum_{k=0}^{\lfloor n/2 \rfloor}
    \min(k, n-2k)
    \right)
    =
    \Theta(n^2)
    \]
</div>

It only stores a fixed number of loop variables and the current result:

<div>
    \[
    S(n) = \Theta(1)
    \]
</div>

# Final Thoughts

This problem is small, but the discussion around it made it more interesting than the problem statement first suggested. One person might immediately see the recurrence, while another sees arrangements of `1`-steps and `2`-steps. Both views are valid, and both count the exact same thing.

That is the useful lesson: different perspectives do not always compete with each other. Sometimes they just put different labels on the same underlying structure. That is usually where the fun part of these small algorithm problems starts.
