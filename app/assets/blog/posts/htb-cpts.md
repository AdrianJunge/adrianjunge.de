---
description: My experience completing the Hack The Box Certified Penetration Testing Specialist (HTB CPTS) certification. I share the journey, rough timeline, exam tips, and tools that helped me succeed.
categories:
    - Penetration Testing
    - Active Directory
    - Privilege Escalation
    - Web Exploitation
year: 2026
published: "2026-03-23"
---
# 1. My Background<a id="my-background"></a>

I started the [CPTS](https://academy.hackthebox.com/preview/certifications/htb-certified-penetration-testing-specialist) path with quite a bit of CTF experience, some hands-on pentest exposure from a university course, and earlier practice on platforms like [TryHackMe](https://tryhackme.com/). That background helped me a lot with enumeration, exploiting common weaknesses, and staying organized under time pressure. A lot of my CTF focus is on web exploitation, which definitely helped during CPTS because quite a bit of the content is web-related. Still, CTFs and pentesting are two very different worlds. CTFs often lean more toward vulnerability research, puzzle solving, and recognizing patterns in isolated targets with a much smaller scope. Pentesting is more methodical, more realistic, and more about building a complete attack path across a real network. CPTS captured that difference very well. It is a strong hands-on foundation that teaches practical pentesting methodology, not just point-and-shoot exploitation, and it forces real understanding and independent thinking rather than relying on copied commands or walkthrough-style learning. Even with my computer science background, the effort to pass CPTS was not negligible. I would say the exam itself was not too hard, but the combination of the full pentest job-role path and the **10-day** exam was a massive time investment. The biggest advantage from my background was not that I already knew every attack. It was that I was used to analytical problem solving, documenting steps, and thinking in terms of attack paths. That turned out to be very useful once the exam started. Still, CPTS was not "just another CTF" for me. The Active Directory part and Windows privilege escalation were the areas that felt genuinely new to me. Everything else was mostly within the range of things I had already seen before, at least in some form.

# 2. Course Content and Time Investment<a id="course-content-and-time-investment"></a>

The full report for my exam ended up being **185 pages**. That sounds enormous, but CPTS pushes you toward being very systematic, and the report reflects that mindset. You have to document every important step, explain the attack path clearly, and include findings even when they lead nowhere. And believe me, the exam contains plenty of rabbit holes. For the course content itself, I spent roughly **30 days** with a mix of full-time and part-time effort working through it. Since I was a student between semesters and also just had a low-hours job next to my studies, I had a lot of time available, and that helped a lot. CPTS is not something I would recommend rushing through. A big part of that time went into building structured notes and writing a few scripts that saved me a lot of time later. The work on the notes paid off twice: once during the exam, and again while writing the report. Good notes are not optional here. They are part of the whole process, and they remain useful even after you pass the exam. The content is broad, but it is not equally strong everywhere. I found some sections, especially Active Directory, to be excellent, while others like Password Attacks felt less polished by comparison.

# 3. What Felt New, What Felt Familiar<a id="what-felt-new-what-felt-familiar"></a>

The part that felt freshest to me was definitely the Active Directory content. That section was deep, detailed, and honestly the most valuable part of the course for me. Windows privilege escalation was also new enough that I had to slow down and really absorb it. The rest was much more familiar. Coming from CTFs and prior platform practice, I already had a decent workflow for enumeration, web exploitation, password cracking, Linux privilege escalation, and general exploitation thinking. That meant CPTS did not feel like learning a brand-new universe. It felt more like leveling up the way I already worked.

# 4. Exam Approach and Timeline<a id="exam-approach-and-timeline"></a>

The exam takes the penetration tester through a full simulated pentest against an enterprise client. It was not an enormous environment, but it felt realistic, and of course a professional report is expected at the end. One thing I especially liked was how interconnected everything felt. It did not feel like a set of isolated boxes, but more like a living environment that gave you the impression of working on a real engagement. I went into it with a cold start: no extra HTB machines, no warm-up lab, and no “let me just do one more box first”. I simply went for it, without any regrets. I also managed to pass the certification on my first attempt, which made the whole experience even more rewarding. The exam is also very tool-flexible and practice-oriented, with far fewer artificial restrictions than some other certifications. The pure pentesting part took me about **4.5** days to collect every single flag, including the last two flags that are usually not necessary to pass the exam. That was more than full-time in the literal sense. I basically sat at my desk from morning to midnight, treating it like a full-time job, just with more stress and fewer breaks. After that came the report, which took the remaining **5.5** days part-time. Compared to the pentest phase, the report felt calmer, but I still spent those days working on it instead of rushing through it at the end. Overall, I would describe the exam as a very intense stretch of work. The individual tasks were definitely manageable, but the real challenge was staying focused over several consecutive days. Some flags also had a slightly guessy character, or I simply overlooked small details. Most of the time when I got stuck, it was because a set of credentials was hiding in the last place I checked. The exam is long and report-driven, and it feels much more like an extended real-world engagement than a short challenge.

# 5. Flag by Flag<a id="where-the-time-went-during-the-exam"></a>

I did not track every single flag with a stopwatch, but the time investment was clearly uneven. Some flags were relatively straightforward once the right path was clear. Others took significantly longer because they required several steps, deeper enumeration, or careful pivoting. The hardest parts were usually not the most obvious ones, but the ones where one missed detail could cost a lot of time. The Active Directory-heavy parts also tended to be more time-consuming for me, not because they were really hard, but because they demanded a more complete mental model of the environment. To me, the most time-consuming flags were **#1**, **#6**, and **#8**. The others were mostly pretty straightforward and required only a few steps.

# 6. Report Writing<a id="report-writing"></a>

The report was a real part of the exam, not an afterthought. Because I already had some experience from writing CTF reports and publishing writeups, I was not starting from zero psychologically. That helped a lot. Still, CPTS reporting is serious enough that it deserves proper structure and enough detail to make the attack chain readable from start to finish. For me, the best approach was to keep notes in a way that already looked like future report sections. That saved a lot of pain later. During the exam, I made sure to copy every useful command and every meaningful output into my notes, because trying to reconstruct everything after the fact would have been a nightmare. When writing the report, I focused on reproducing a clear attack chain and added screenshots where they improved readability and clarity.

# 7. Tips for the Exam and the Report<a id="tips-for-the-exam-and-the-report"></a>

The most important lesson is simple: **good notes are everything**. If your notes are structured well during the course, you are already giving yourself a huge advantage for both the exam and the report. A few other things mattered a lot for me:
**-** Even small remarks from the content can be useful later; tiny details can turn into a breakthrough.
**-** The last module felt very similar to one of the exam machines, so do not treat the final module as "just another chapter" but more as a test before the exam.
**-** Exam machines are not equally expensive in terms of time; some move fast, others eat your day.
**-** During the exam, copy everything relevant: commands, outputs, screenshots, and context, because your future self will thank you for it.
**-** Learn and use [ligolo-ng](https://github.com/nicocha30/ligolo-ng). For me, it was a huge quality-of-life improvement for pivoting compared to the more elaborate combination of [Chisel](https://github.com/jpillora/chisel) and [Proxychains](https://github.com/haad/proxychains).

# 8. How I Would Summarize CPTS<a id="how-i-would-summarize-cpts"></a>

CPTS was a lot of work, but it was good work. It gave me a much stronger methodology, especially around Active Directory, disciplined enumeration, and report writing. It also forced me to be more patient and more structured than I would normally be in a CTF setting. The biggest technical value of CPTS is that it makes you actually understand what you are doing instead of just following commands. If I had to summarize the whole journey in one sentence, I would say this: CPTS is not about rushing through boxes, but about proving that you can think, document, and execute like someone who is actually doing the job.

# 9. Final Thoughts<a id="final-thoughts"></a>

The biggest difference between this and pure CTF-style learning was the pace. CPTS made me slow down, write better notes, and care about completeness instead of just "getting the flag". For me, that was exactly the value of it. I would still recommend going into it with a lot of time, a disciplined note-taking setup, and the expectation that the exam is a serious multi-day effort rather than a quick challenge. The biggest downside, in my opinion, is the time commitment — both for finishing the course and for surviving the **10-day** exam window, especially if you are working full time next to it and cannot freely use work hours to prepare. The learning experience and the practical knowledge you gain from CPTS are absolutely worth it. If you are currently preparing for it yourself, I wish you the best of luck and a lot of perseverance on your own CPTS journey.

# 10. Certificate<a id="Certificate"></a>
Check out the badge on [credly](https://www.credly.com/badges/a9a49759-8f35-4c46-8783-a11a4a1bfdf0/public_url).

![certificate](blog/posts/htb-cpts/cpts-certificate.png "certificate")
