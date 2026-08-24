import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const sourceUrl = new URL('../../app/javascript/content_filters.js', import.meta.url);
const source = await readFile(sourceUrl, 'utf8');
const filters = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);

test('search normalization removes accents and punctuation', () => {
  assert.equal(filters.normalizeToken('  Mixed CASE  '), 'mixed case');
  assert.equal(filters.normalizeSearchValue('Café / CVE-2099'), 'cafecve2099');
  assert.deepEqual(filters.normalizeSearchWords('Café / CVE-2099'), [ 'cafe', 'cve', '2099' ]);
});

test('ordered character matching supports fuzzy terms without reordering', () => {
  assert.equal(filters.orderedCharacterMatch('prvlg', 'privilege'), true);
  assert.equal(filters.orderedCharacterMatch('pglvr', 'privilege'), false);
  assert.equal(filters.orderedCharacterMatch('', 'anything'), true);
});

test('search matches every query term against text, tag words, or compact tags', () => {
  const terms = filters.searchTermsFrom(
    'Café memory corruption',
    [ 'Privilege Escalation', 'Web' ]
  );

  assert.equal(filters.matchesSearchQuery('cafe prvlg', terms), true);
  assert.equal(filters.matchesSearchQuery('privilegeescalation', terms), true);
  assert.equal(filters.matchesSearchQuery('crypto', terms), false);
});

test('card matching combines search, year, and all selected tags', () => {
  const record = {
    searchTerms: filters.searchTermsFrom('Fixture writeup', [ 'Web', 'Hard' ]),
    tagSet: new Set([ 'web', 'hard' ]),
    yearSet: new Set([ '2025' ])
  };

  assert.equal(filters.matchesCardRecord(record, [ 'fxture' ], '2025', [ 'web', 'hard' ]), true);
  assert.equal(filters.matchesCardRecord(record, [ 'fxture' ], '2024', [ 'web', 'hard' ]), false);
  assert.equal(filters.matchesCardRecord(record, [ 'fxture' ], '2025', [ 'crypto' ]), false);
});

test('pipe-delimited values and URL tag parameters normalize consistently', () => {
  assert.deepEqual(filters.tokensFrom(' Web | HARD || '), [ 'web', 'hard' ]);

  const params = new URLSearchParams('tag=Web&tag=Pwn%7CCrypto&tags=Hard,Easy');
  assert.deepEqual(filters.tagValuesFromParams(params), [ 'web', 'pwn', 'crypto', 'hard', 'easy' ]);
});

test('uncombinable tags exclude active and currently available choices', () => {
  const records = [ { tags: [ 'web', 'pwn' ] } ];
  const chips = [ 'Web', 'Pwn', 'Crypto' ].map(filterTag => ({ dataset: { filterTag } }));

  assert.deepEqual(
    filters.uncombinableTagsFor(records, new Set([ 'web' ]), chips),
    new Set([ 'crypto' ])
  );
});

test('unknown year values reset while known values remain selected', () => {
  const select = { options: [ { value: '' }, { value: '2024' }, { value: '2025' } ] };

  assert.equal(filters.validSelectValue(select, '2025'), '2025');
  assert.equal(filters.validSelectValue(select, '2099'), '');
  assert.equal(filters.validSelectValue(null, '2025'), '2025');
});
