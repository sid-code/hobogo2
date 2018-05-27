import 'dart:convert';
import 'dart:async';
import 'levenshtein.dart';

class Fuzzy {
  //https://stackoverflow.com/questions/5924105/how-many-characters-can-be-mapped-with-unicode
  //static final int _charMax = 17 * 65536 - 2048 - 66;
  static final int _charMax = 128;
  static final List<int> _patternMask = new List<int>(_charMax + 1);
  Fuzzy() {
    for (int i = 0; i <= _charMax; ++i) {
      _patternMask[i] = ~0;
    }
  }

  //Ok so max distance is nonsense, found some magic from github
  int bitapSearch(String textStr, String patternStr, int maxDistance) {
    Completer<int> c = new Completer<int>();
    maxDistance = (patternStr.length * .25).floor();
    Utf8Codec u8codec = new Utf8Codec();
    List<int> text = u8codec.encode(textStr.toLowerCase());
    List<int> pattern = u8codec.encode(patternStr.toLowerCase());
    int retVal = -1;
    int m = pattern.length;
    List<int> R = new List<int>(maxDistance + 1);
    List<int> patternMask = new List.from(_patternMask);
    for (int i = 0; i <= maxDistance; ++i) {
      R[i] = ~1;
    }
    for (int i = 0; i < m; ++i) {
      patternMask[pattern[i]] &= ~(1 << i);
    }

    for (int i = 0; i < text.length; ++i) {
      int oldRd1 = R[0];

      R[0] |= patternMask[text[i]];
      R[0] <<= 1;

      for (int d = 1; d <= maxDistance; ++d) {
        int tmp = R[d];

        R[d] = (oldRd1 & (R[d] | patternMask[text[i]])) << 1;
        oldRd1 = tmp;
      }

      if (0 == (R[maxDistance] & (1 << m))) {
        retVal = (i - m) + 1;
        break;
      }
    }
    //c.complete(retVal);
    //return c.future;
    if(retVal != -1){
      print('retVal not -1');
      print(retVal);
    }
    return retVal;
  }
}
