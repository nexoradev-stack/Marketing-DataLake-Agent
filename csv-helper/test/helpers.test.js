// Unit tests for the pure helper functions in index.js.
// Run with: npm test   (no Google Cloud access needed)

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  friendlyName,
  parseMeta,
  parseCsv,
  countCsvRows,
  extractEmails,
  eventKey,
  nameFromEmail,
  isFirstShard
} = require('../index.js');

test('eventKey: same event when only capitals, dashes and spaces differ', () => {
  const a = eventKey('Engineering the Agentic Enterprise – Atlanta');
  const b = eventKey('engineering the agentic enterprise atlanta');
  const c = eventKey('Engineering the Agentic Enterprise - ATLANTA');
  assert.equal(a, 'engineeringtheagenticenterpriseatlanta');
  assert.equal(a, b);
  assert.equal(a, c);
});

test('eventKey: different words are a different event', () => {
  assert.notEqual(
    eventKey('Engineering the Agentic Enterprise – Atlanta'),
    eventKey('Gemini Product Updates – Atlanta')
  );
  assert.notEqual(
    eventKey('Webinar: Google Gemini Updates – Atlanta'),
    eventKey('Google Gemini Updates Atlanta')
  );
});

test('eventKey: empty input', () => {
  assert.equal(eventKey(''), '');
  assert.equal(eventKey(undefined), '');
});

test('parseCsv: handles quotes, commas and escaped quotes', () => {
  const rows = parseCsv('a,b\n"x, y","he said ""hi"""\n');
  assert.deepEqual(rows, [['a', 'b'], ['x, y', 'he said "hi"']]);
});

test('parseCsv: ignores blank lines and Windows line endings', () => {
  const rows = parseCsv('a,b\r\n1,2\r\n\r\n');
  assert.deepEqual(rows, [['a', 'b'], ['1', '2']]);
});

test('countCsvRows: counts data rows only', () => {
  assert.equal(countCsvRows('h1,h2\n1,2\n3,4\n'), 2);
  assert.equal(countCsvRows('h1,h2\n'), 0);
  assert.equal(countCsvRows(''), 0);
});

test('extractEmails: reads the Email ID column, lowercases and de-duplicates', () => {
  const csv = [
    'Company Name,Email ID,Industry',
    'Acme,Jordan.Lee@Acme.example,"Financial Services, Banking"',
    'Acme,jordan.lee@acme.example,Retail',
    'Globex,priya@globex.example,Retail',
    'Empty,,Retail'
  ].join('\n');
  assert.deepEqual(extractEmails(csv), ['jordan.lee@acme.example', 'priya@globex.example']);
});

test('extractEmails: no Email ID column returns nothing', () => {
  assert.deepEqual(extractEmails('Company Name,Email\nAcme,a@b.example\n'), []);
});

test('parseMeta: reads every key from the META line', () => {
  const query = [
    '-- META | event=Cloud Leaders Summit – Texas | solution=Data & AI | industry=Healthcare | titles=CIO, CTO; added: CDO | location=Any, Texas, United States | requested=300',
    'EXPORT DATA OPTIONS(...) AS SELECT 1'
  ].join('\n');
  const meta = parseMeta(query);
  assert.equal(meta.event, 'Cloud Leaders Summit – Texas');
  assert.equal(meta.solution, 'Data & AI');
  assert.equal(meta.industry, 'Healthcare');
  assert.equal(meta.titles, 'CIO, CTO; added: CDO');
  assert.equal(meta.location, 'Any, Texas, United States');
  assert.equal(meta.requested, '300');
});

test('parseMeta: falls back to the last LIMIT when requested is missing', () => {
  const meta = parseMeta('SELECT * FROM (SELECT 1 LIMIT 5) LIMIT 25');
  assert.equal(meta.requested, '25');
});

test('friendlyName: builds the download name', () => {
  assert.equal(
    friendlyName('exports/20261106060222_8236a5/Cloud_Leaders_Summit_Texas_000000000000.csv'),
    'Database - Cloud Leaders Summit Texas.csv'
  );
});

test('isFirstShard: only the first file of an export', () => {
  assert.equal(isFirstShard('exports/x/Event_000000000000.csv'), true);
  assert.equal(isFirstShard('exports/x/Event_000000000001.csv'), false);
});

test('nameFromEmail: turns an email into a display name', () => {
  assert.equal(nameFromEmail('jordan.lee@example.com'), 'Jordan Lee');
  assert.equal(nameFromEmail(''), 'Unknown user');
});
