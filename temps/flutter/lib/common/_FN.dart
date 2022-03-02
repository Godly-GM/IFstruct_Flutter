part of 'FN.dart';

final warn = print;
final log = print;

var flowCache = {};
var flowPS = {};
var __currentClone__ = {};

updateFlow(name, data) {
  try {
    String mid = $models[name]['id'];

    flowCache[mid].add(data);
  } catch (e) {
    print('updateFlow error: $name $data');
    print(e);
  }
}

setCurrentClone(hid, clone) {
  var cclone = __currentClone__;
  cclone[hid] = clone;

  var item = $struct[hid];
  if (item != null) {
    item['children'].forEach((id) {
      if (cclone[id] != null || (cclone[id] != null && !cclone[id].startsWith(clone))) {
        setCurrentClone(id, clone);
      }
    });
  }
}

removeCurrentClone(hid) {
  __currentClone__[hid] = null;
  
  var item = $sets[hid];
  if (item) {
    item.children.forEach((id) {
      __currentClone__[id] = null;
    });
  }
}

finder(paths, data) {
  var p = data;
  paths.forEach((e) {
    p = p[e];
  });
  return p;
}

sumDeepth(arr, flag) {
  return arr.reduce((total, item) {
    var totalDeepth;
    if (item is List) {
      totalDeepth = sumDeepth(item, flag + 1);
    }
    return totalDeepth > total ? totalDeepth : total;
  }, flag);
}

getArrayDeepth(array) {
  if (!(array is List)) return 0;

  return sumDeepth(array, 1);
}

subExpCheck(exps, v, I, hid) {
  v = v.toString(); // Number to string.

  try {
    var exp = exps;
    // The regular occupies a separate place in the expression and can be returned directly.
    RegExp regReg = RegExp(r"^\${(.+)}$");

    var rreg = regReg.firstMatch(exp);

    if (rreg is RegExpMatch) {
      var g = rreg.group(1) ?? '';

      return RegExp(g).hasMatch(v);
    }

    // odd even
    int calc = int.parse(v) % 2;

    if (exp == '\$odd') {
      return calc == 1;
    }

    if (exp == '\$even') {
      return calc != 1;
    }

    if (exp == '\$N') {
      return true;
    }

    RegExp regNumber = RegExp(r"\$\d+");

    var nreg = regNumber.allMatches(exp);
    if (nreg.length > 0) {
      nreg.forEach((m) {
        var md = m.group(0) ?? '';

        exp = exp.replaceAll(md, md.substring(1));
      });
    }

    var modelReg = RegExp(r"\$([a-zA-Z]\w+)<*(\w*)>*").allMatches(exp);
    if (modelReg.length > 0) {
      modelReg.forEach((m) {
        var md = m.group(0);

        var mdv = parseModelExp(md, hid, true);

        if (mdv == '') mdv = '0';

        exp = exp.replaceAll(md, mdv);
      });
    }

    // Match at will and return directly.
    if (exp.contains('\$n')) {
      if (__currentClone__[hid] == null) {
        return false;
      }
      var curr = __currentClone__[hid].split('|')[I + 1];

      exp = exp.replaceAll('\$n', curr);
    }

    if (exp.contains('\$i')) {
      exp = exp.replaceAll('\$i', v);
    }

    // Add eval to support dynamic calculations.
    exp = evalJS(exp);

    return exp is bool ? exp : exp.toString() == v;
  } catch (e) {
    warn('exp is invalid.');
    warn(e);
    return false;
  }
}

// ei => exp index
subExpFilter(exps, data, hid, int ei) {
  if (!(data is List) || exps.length < 1) return data;

  var exp = exps.removeAt(0);

  int i = 0;
  List arr = data.where((sub) {
    bool flag = subExpCheck(exp, i, ei, hid);

    i += 1;

    return flag;
  }).toList();

  return arr.map((v) => subExpFilter(exps, v, hid, ei + 1)).toList();
}

// handle is the parent object.
subExpWrite(exps, data, hid, ei, value, handle, hi, key) {
  if (ei == null) ei = 0;
  if (handle == null) handle = null;
  if (hi == null) hi = 0;

  if (!(data is List) || !exps.length) {
    if (handle) {
      handle.value[key].value['value'].value[hi] = value;
    }

    return;
  } 

  var exp = exps.removeAt(0);

  int i = 0;
  data.forEach((sub) {
    if (subExpCheck(exp, i, ei, hid)) {
      subExpWrite(exps, sub, hid, ei + 1, value, data, i, key);
    }

    i += 1;
  });
}

ModelHandle(id, key, $item) {
  String sid = id + '.' + key;

  if (flowPS[sid] == null) {
    var model = $item['model'].value;
    var md = model[key];

    if (md == null) return;

    var uk = md.value['use'];

    if (uk != null) {
      
      var tb = uk.split('.')[0];

      if (flowCache[tb] == null) {
        flowCache[tb] = BehaviorSubject();
      }
      
      flowPS[sid] = flowCache[tb].stream.listen((v) {
        subscribeFlow(tb, id, key, v);
      });
    }
  }
}

parseModelStr(target, hid) {
  if (!(target is String) || target == '') return target;

  if (target.indexOf('# ') == 0) return parseModelExp(target, hid, true);

  if (target.substring(0, 1) != '\$') return target;

  if (target == '\$current') return hid;

  RegExp regNs = RegExp(r"\$([a-zA-Z]\w+)<(.+)>");

  var select = regNs.firstMatch(target); // eg: "$Bo<Global>" => "$Bo<Global>", "Bo", "Global"
  try {
    var key;
    var id;
    var sets;
    if (select is RegExpMatch) {

      key = select.group(1);
      id = select.group(2);
    } else {
      key = target.substring(1);
      id = hid;
    }

    sets = $sets[id].value;

    var model = sets['model'].value[key];

    if (model == null) return '';

    target = parseModelStr(model.value['value'], id);
  } catch (e) {
    warn('parseModelStr $e is invalid.');
    target = '';
  }

  return target;
}

parseModelExp(exp, hid, runtime) {
  if (runtime == null) runtime = true;

  if (!(exp is String)) return exp;

  bool isComputed = exp.indexOf('# ') == 0;

  if (!exp.contains('\$') && !isComputed) return exp;

  if (exp == '') return exp;

  RegExp regModel = RegExp(r"\$([a-zA-Z]\w+)(_\w+)?(<.+?>)?");

  var list = regModel.allMatches(exp);

  list.forEach((m) {
    var ms = m.group(0);
    var V =  parseModelStr(ms, hid);

    if (runtime || isComputed) {
      V = V is String ? '"$V"' : (V is Map || V is List ? jsonEncode(V) : V);
    }

    exp = exp.replaceAll(ms, V.toString());
  });

  if (isComputed) {
    return evalJS(exp.substring(2));
  }

  return exp;
}

arrFirst(arr) {
  if (arr is List && arr.length < 2) {
    return arrFirst(arr[0]);
  } else {
    return arr;
  }
}

tfClone(clone) {
  return clone.split('|').where((v) => v != '').map((v) => '\$' + v).toList().join(':');
}

fillArr(value, road) {
  var r = road[0];
  if (r == 'n') {
    road.removeAt(0);

    if (road.length > 1) {
      var k = road[0];

      return List<int>.filled(value.length, 0, growable: true).asMap().keys.map((i) {
        return fillArr(value[i][k], road.take(1));
      });
    } else {
      return value.map((obj) => obj[road[0]]).toList();
    }
  } else {
    value = value[r];

    road.removeAt(0);

    return fillArr(value, road);
  }
}

subscribeFlow(tid, hid, key, value) {
  var $item = $sets[hid].value;

  var model = $item['model'].value;
  var md = model[key];
  var uk = md.value['use'];

  var target = model[key];

  List path = uk.split('.');
  
  if (path[0] != tid || value == null) return false;

  var D = path.skip(1).where((v) => v == 'n').length; // ZI
  var V;

  if (D > 0) {
    V = fillArr(value, path.skip(1));

    target.value['value'] = V;
  } else {
    path.skip(1).forEach((p) {
      value = value[p];
    });

    V = value;

    target.value['value'] = value;
  }
}

parseTransition(str) {
  var tarr = str.split(' ').skip(1).toList();
  var during = tarr.removeAt(0);

  if (during.endsWith('s')) {
    during = double.parse(during.substring(0, during.indexOf('s')));
  }
  var curve = tarr.join(''); // eg: cubic-bezier(0.47, 0, 0.745, 0.715)
  var cv = curve.substring(curve.indexOf('(') + 1, curve.indexOf(')')).split(',');

  return [during, bezier(cv[0], cv[1], cv[2], cv[3])];
}

Cubic bezier(a, b, c, d) {
  return Cubic(double.parse(a), double.parse(b), double.parse(c), double.parse(d));
}

Cubic parseBezier(str) {
  if (str is Cubic) return str;
  if (!str.contains('(')) return $bezier[str] ?? Cubic(0, 0, 1, 1);

  String curve = str.replaceAll(' ', '');
  List cv = curve.substring(curve.indexOf('(') + 1, curve.indexOf(')')).split(',');

  return bezier(cv[0], cv[1], cv[2], cv[3]);
}