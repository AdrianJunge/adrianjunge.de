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
        'Some people collect stamps. I collect stack traces.',
        'My favorite input is the one nobody validated.',
        'Politely asking software uncomfortable questions.',
        'CTF enthusiast',
        'I like puzzles that crash systems.',
        'Turning weird behavior into writeups.',
        'Teaching machines to misbehave.',
        'CTF flags, real bugs, questionable sleep schedule.',
        'Web and PWN player',
        'Your browser knows everything - XSLeaks just politely ask',
        'Source code tells jokes in edge cases.',
        'I love breaking stuff so others can fix it.',
        'Making impossible states feel very possible.',
        'The best exploit starts with: wait, that is weird.',
        'If it runs, I poke it.',
        'If it parses, I probably want to test it.',
    ];

    new RandomTyped(el, {
        strings: phrases,
        typeSpeed: 50,
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
