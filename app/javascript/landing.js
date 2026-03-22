import Typed from "typed.js";

class RandomTyped extends Typed {
    async typewrite(chars, curString, curStrPos) {
        if (!this.el) return;
        const randomSpeed = Math.floor(Math.random() * 50) + 25;
        await new Promise(r => setTimeout(r, randomSpeed));
        super.typewrite(chars, curString, curStrPos);
    }
}

document.addEventListener("DOMContentLoaded", function () {
    const el = document.getElementById('typing');
    if (!el) return;

    const phrases = [
        'Discover here my CTF writeups & projects',
        'Web and occasionally PWN player',
        'CTF enthusiast',
        'Your browser knows everything - XSLeaks just politely ask',
        'I love breaking stuff so others can fix it',
        'I write to deepen my understanding, and maybe it actually helps others along the way',
        'If it runs, I poke it',
        'I like puzzles that crash systems',
        'Teaching machines to misbehave',
        // 'Currently learning: <TODO>'
    ];

    new RandomTyped(el, {
        strings: phrases,
        typeSpeed: 100,
        backSpeed: 50,
        backDelay: 2000,
        startDelay: 600,
        loop: true,
        smartBackspace: true,
        showCursor: true,
        cursorChar: '|',
        shuffle: true,
    });
});
