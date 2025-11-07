#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const DEFAULT_MAX_FILE_SIZE = 512 * 1024; // 512 KB
const IGNORED_DIRECTORIES = new Set([
  '.git',
  'node_modules',
  '.next',
  'dist',
  'build',
  'out',
  'coverage',
  'docSite/public',
  'docSite/resources',
  'node-compile-cache',
  'bin'
]);

const COMMON_WORDS = ['the', 'this', 'that', 'flag', 'fast', 'agent', 'message', 'secret'];

const base64Regex = /(?<![A-Za-z0-9+/=])([A-Za-z0-9+/]{24,}={0,2})(?![A-Za-z0-9+/=])/g;
const hexRegex = /(?<![0-9a-fA-F])([0-9a-fA-F]{32,})(?![0-9a-fA-F])/g;
const rot13Regex = /([A-Z]{4,}(?:\s+[A-Z]{4,}){2,})/g;

function walkDirectory(root, onFile) {
  const stack = [root];
  while (stack.length > 0) {
    const current = stack.pop();
    let entries;
    try {
      entries = fs.readdirSync(current, { withFileTypes: true });
    } catch (error) {
      continue;
    }

    for (const entry of entries) {
      const fullPath = path.join(current, entry.name);
      if (entry.isDirectory()) {
        if (shouldSkipDirectory(fullPath)) continue;
        stack.push(fullPath);
      } else if (entry.isFile()) {
        onFile(fullPath);
      }
    }
  }
}

function shouldSkipDirectory(dirPath) {
  for (const ignored of IGNORED_DIRECTORIES) {
    if (dirPath.includes(`${path.sep}${ignored}`)) {
      return true;
    }
  }
  return false;
}

function isMostlyPrintable(text) {
  if (!text) return false;
  let printableCount = 0;
  for (const char of text) {
    const code = char.charCodeAt(0);
    if (
      (code >= 32 && code <= 126) ||
      char === '\n' ||
      char === '\r' ||
      char === '\t'
    ) {
      printableCount += 1;
    }
  }
  return printableCount / text.length >= 0.8;
}

function decodeBase64(candidate) {
  try {
    const buffer = Buffer.from(candidate, 'base64');
    const text = buffer.toString('utf8');
    return isMostlyPrintable(text) ? text : null;
  } catch (error) {
    return null;
  }
}

function decodeHex(candidate) {
  if (candidate.length % 2 !== 0) return null;
  try {
    const buffer = Buffer.from(candidate, 'hex');
    const text = buffer.toString('utf8');
    return isMostlyPrintable(text) ? text : null;
  } catch (error) {
    return null;
  }
}

function decodeRot13(text) {
  return text.replace(/[A-Z]/g, (char) => {
    const code = char.charCodeAt(0) - 65;
    return String.fromCharCode(((code + 13) % 26) + 65);
  });
}

function containsCommonWord(text) {
  const lowered = text.toLowerCase();
  return COMMON_WORDS.some((word) => lowered.includes(word));
}

function analyzeText(text, filePath) {
  const findings = [];

  let match;
  let count = 0;
  while ((match = base64Regex.exec(text)) && count < 5) {
    const decoded = decodeBase64(match[1]);
    if (decoded) {
      findings.push({
        type: 'base64',
        snippet: match[1].slice(0, 60) + (match[1].length > 60 ? '…' : ''),
        decoded,
        index: match.index
      });
      count += 1;
    }
  }

  count = 0;
  while ((match = hexRegex.exec(text)) && count < 5) {
    const decoded = decodeHex(match[1]);
    if (decoded) {
      findings.push({
        type: 'hex',
        snippet: match[1].slice(0, 60) + (match[1].length > 60 ? '…' : ''),
        decoded,
        index: match.index
      });
      count += 1;
    }
  }

  count = 0;
  while ((match = rot13Regex.exec(text)) && count < 5) {
    const decoded = decodeRot13(match[1]);
    if (decoded !== match[1] && containsCommonWord(decoded)) {
      findings.push({
        type: 'rot13',
        snippet: match[1],
        decoded,
        index: match.index
      });
      count += 1;
    }
  }

  if (findings.length > 0) {
    console.log(`\n>>> Potential secrets in: ${filePath}`);
    findings
      .sort((a, b) => a.index - b.index)
      .forEach((finding, idx) => {
        console.log(`  [${idx + 1}] Type: ${finding.type}`);
        console.log(`      Raw: ${finding.snippet}`);
        console.log(`      Decoded: ${finding.decoded.trim()}`);
      });
  }
}

function analyzeFile(filePath) {
  let stats;
  try {
    stats = fs.statSync(filePath);
  } catch (error) {
    return;
  }
  if (stats.size === 0 || stats.size > DEFAULT_MAX_FILE_SIZE) return;

  let content;
  try {
    content = fs.readFileSync(filePath, 'utf8');
  } catch (error) {
    return;
  }

  if (!isMostlyPrintable(content)) return;

  analyzeText(content, filePath);
}

function main() {
  const targetDir = process.argv[2] ? path.resolve(process.argv[2]) : process.cwd();
  console.log(`Scanning directory: ${targetDir}`);
  const start = Date.now();
  walkDirectory(targetDir, analyzeFile);
  const end = Date.now();
  console.log(`\nScan completed in ${(end - start) / 1000}s.`);
}

if (require.main === module) {
  main();
}
