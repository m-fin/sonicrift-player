import assert from 'node:assert/strict';
import test from 'node:test';

import { seekRatio } from './seek-ratio';

test('uses locationX when the press includes it', () => {
  assert.equal(seekRatio({ locationX: 25, width: 100 }), 0.25);
});

test('falls back to page coordinates when locationX is missing', () => {
  assert.equal(seekRatio({ width: 0, pageX: 150, originX: 100, originWidth: 200 }), 0.25);
});

test('ignores a non-finite press', () => {
  assert.equal(seekRatio({ locationX: Number.NaN, width: 100 }), null);
  assert.equal(seekRatio({ width: 100 }), null);
});
