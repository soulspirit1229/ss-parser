'use strict';

Object.defineProperty(exports, "__esModule", {
  value: true
});

var _fs = require('fs');

var _fs2 = _interopRequireDefault(_fs);

var _async = require('async');

var _async2 = _interopRequireDefault(_async);

var _lodash = require('lodash');

var _lodash2 = _interopRequireDefault(_lodash);

var _checksum = require('checksum');

var _checksum2 = _interopRequireDefault(_checksum);

var _glob = require('glob');

var _glob2 = _interopRequireDefault(_glob);

var _parseContents = require('./parseContents');

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

// Whenever a breaking change occurs, update this version number and the corresponding
// supported version number in SuperScript
const VERSION_NUMBER = 1;

const parseFile = function parseFile(path, factSystem, callback) {
  const startTime = Date.now();
  _fs2.default.readFile(path, 'utf-8', (err, contents) => {
    if (err) {
      return callback(`Error reading file: ${err}`);
    }
    return (0, _parseContents.parseContents)(contents, factSystem, (err, parsed) => {
      if (err) {
        return callback(`Error whilst processing file: ${path}\n${err}`);
      }
      parsed.version = VERSION_NUMBER;
      console.log(`Time to process file ${path}: ${(Date.now() - startTime) / 1000} seconds`);
      return callback(err, parsed);
    });
  });
};

const findFilesToProcess = function findFilesToProcess(path, cache, callback) {
  (0, _glob2.default)(`${path}/**/*.ss`, (err, files) => {
    if (err) {
      return callback(err);
    }

    const checksums = {};
    const checkInCache = (file, next) => {
      _checksum2.default.file(file, (err, sum) => {
        if (err) {
          return next(err);
        }

        checksums[file] = sum;
        if (cache[file]) {
          return next(null, cache[file] !== sum);
        }
        return next(null, true);
      });
    };

    // Filters out files that have been cached already
    return _async2.default.filter(files, checkInCache, (err, filesToLoad) => {
      if (err) {
        return callback(err);
      }

      return callback(null, filesToLoad, checksums);
    });
  });
};

// Cache is a key:sum of files
const parseDirectory = function parseDirectory(path, options, callback) {
  if (_lodash2.default.isFunction(options)) {
    callback = options;
    options = {};
  }

  // Doesn't matter if this is null, we just decide not to use facts in wordnet expansion
  const factSystem = options.factSystem;
  const cache = options.cache || {};

  const startTime = new Date().getTime();

  findFilesToProcess(path, cache, (err, files, checksums) => {
    if (err) {
      return callback(err);
    }

    return _async2.default.map(files, (fileName, callback) => {
      parseFile(fileName, factSystem, callback);
    }, (err, res) => {
      if (err) {
        return callback(err);
      }

      let topics = {};
      let gambits = {};
      let replies = {};

      for (let i = 0; i < res.length; i++) {
        topics = _lodash2.default.merge(topics, res[i].topics);
        gambits = _lodash2.default.merge(gambits, res[i].gambits);
        replies = _lodash2.default.merge(replies, res[i].replies);
      }

      const data = {
        topics,
        gambits,
        replies,
        checksums,
        version: VERSION_NUMBER
      };

      const topicCount = Object.keys(topics).length;
      const gambitsCount = Object.keys(gambits).length;
      const repliesCount = Object.keys(replies).length;

      console.log(`Total time to process: ${(Date.now() - startTime) / 1000} seconds`);
      console.log("Number of topics %s parsed.", topicCount);
      console.log("Number of gambits %s parsed.", gambitsCount);
      console.log("Number of replies %s parsed.", repliesCount);

      if (topicCount !== 0 && gambitsCount !== 0 && repliesCount !== 0) {
        return callback(null, data);
      }

      return callback(null, {});
    });
  });
};

exports.default = {
  normalizeTrigger: _parseContents.normalizeTrigger,
  parseContents: _parseContents.parseContents,
  parseDirectory,
  parseFile
};

// parseDirectory("./chat/", {} , function(err, data) {
//         fs.writeFile("./data.json", JSON.stringify(data, null, 4), (err) => {
//         if (err) throw err;
//         console.log(`Saved output`);
//         process.exit();
//       });
// })