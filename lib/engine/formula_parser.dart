import 'dart:math';

// =============================================================================
// أنواع الرموز (Tokens)
// =============================================================================

/// أنواع الرموز في الصيغة.
enum TokenType {
  number,
  string,
  cellRef,
  rangeRef,
  function,
  operator,
  leftParen,
  rightParen,
  comma,
  error,
}

/// رمز مفرد من الصيغة بعد التحليل المعجمي.
class Token {
  final TokenType type;
  final String value;
  final int position;

  const Token(this.type, this.value, this.position);

  @override
  String toString() => 'Token($type, "$value")';
}

// =============================================================================
// المحلل المعجمي (Lexer)
// =============================================================================

/// يحول نص الصيغة الخام إلى قائمة من الرموز (Tokens).
class FormulaLexer {
  final String input;
  int _pos = 0;
  final List<Token> _tokens = [];

  FormulaLexer(this.input);

  /// ينفذ التحليل المعجمي ويعيد الرموز.
  List<Token> tokenize() {
    _tokens.clear();
    _pos = 0;

    while (_pos < input.length) {
      final ch = input[_pos];

      // مسافات — نتجاوزها
      if (ch == ' ') {
        _pos++;
        continue;
      }

      // أرقام (بما في ذلك الكسور العشرية)
      if (_isDigit(ch) ||
          (ch == '.' && _pos + 1 < input.length && _isDigit(input[_pos + 1]))) {
        _readNumber();
        continue;
      }

      // نصوص بين علامتي اقتباس
      if (ch == '"') {
        _readString();
        continue;
      }

      // معرفات: مراجع خلايا (A1) أو دوال (SUM)
      if (_isLetter(ch) || ch == '_') {
        _readIdentifier();
        continue;
      }

      // عوامل حسابية + المقارنات
      if ('+-*/^%'.contains(ch)) {
        _tokens.add(Token(TokenType.operator, ch, _pos));
        _pos++;
        continue;
      }

      // علامة = (للمقارنة داخل الصيغة)
      if (ch == '=' && _pos > 0) {
        _tokens.add(Token(TokenType.operator, '=', _pos));
        _pos++;
        continue;
      }

      // >=
      if (ch == '>') {
        if (_pos + 1 < input.length && input[_pos + 1] == '=') {
          _tokens.add(Token(TokenType.operator, '>=', _pos));
          _pos += 2;
        } else {
          _tokens.add(Token(TokenType.operator, '>', _pos));
          _pos++;
        }
        continue;
      }

      // <= أو <>
      if (ch == '<') {
        if (_pos + 1 < input.length) {
          if (input[_pos + 1] == '=') {
            _tokens.add(Token(TokenType.operator, '<=', _pos));
            _pos += 2;
          } else if (input[_pos + 1] == '>') {
            _tokens.add(Token(TokenType.operator, '<>', _pos));
            _pos += 2;
          } else {
            _tokens.add(Token(TokenType.operator, '<', _pos));
            _pos++;
          }
        } else {
          _tokens.add(Token(TokenType.operator, '<', _pos));
          _pos++;
        }
        continue;
      }

      // أقواس
      if (ch == '(') {
        _tokens.add(Token(TokenType.leftParen, '(', _pos));
        _pos++;
        continue;
      }
      if (ch == ')') {
        _tokens.add(Token(TokenType.rightParen, ')', _pos));
        _pos++;
        continue;
      }

      // فاصلة (فصل وسائط الدوال)
      if (ch == ',') {
        _tokens.add(Token(TokenType.comma, ',', _pos));
        _pos++;
        continue;
      }

      // نقطتان (نطاق مرجعي A1:B5)
      if (ch == ':') {
        _tokens.add(Token(TokenType.rangeRef, ':', _pos));
        _pos++;
        continue;
      }

      // $ للمرجع المطلق — نتجاوزه حالياً
      if (ch == r'$') {
        _pos++;
        continue;
      }

      // رمز غير معروف — نتجاوزه
      _pos++;
    }

    return _tokens;
  }

  void _readNumber() {
    final start = _pos;
    while (_pos < input.length &&
        (_isDigit(input[_pos]) || input[_pos] == '.')) {
      _pos++;
    }
    _tokens.add(Token(TokenType.number, input.substring(start, _pos), start));
  }

  void _readString() {
    final start = _pos;
    _pos++; // تخطي علامة الاقتباس الافتتاحية
    while (_pos < input.length && input[_pos] != '"') {
      _pos++;
    }
    if (_pos < input.length) {
      _pos++; // تخطي علامة الاقتباس الختامية
    }
    _tokens.add(Token(TokenType.string, input.substring(start, _pos), start));
  }

  void _readIdentifier() {
    final start = _pos;
    while (_pos < input.length &&
        (_isLetter(input[_pos]) ||
            _isDigit(input[_pos]) ||
            input[_pos] == '_' ||
            input[_pos] == '.')) {
      _pos++;
    }
    final word = input.substring(start, _pos).toUpperCase();

    // إذا تبعه ( فهي دالة، وإلا مرجع خلية
    if (_pos < input.length && input[_pos] == '(') {
      _tokens.add(Token(TokenType.function, word, start));
    } else {
      _tokens.add(Token(TokenType.cellRef, input.substring(start, _pos), start));
    }
  }

  bool _isDigit(String ch) =>
      ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;

  bool _isLetter(String ch) {
    final code = ch.codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }
}

// =============================================================================
// أنواع عقد شجرة البناء المجرد (AST)
// =============================================================================

/// أنواع عقد شجرة بناء الجملة المجردة (AST).
enum NodeType {
  number,
  string,
  cellRef,
  rangeRef,
  function,
  binaryOp,
  unaryOp,
  error,
}

/// عقدة في شجرة بناء الجملة المجردة (AST).
class ASTNode {
  final NodeType type;
  final String value;
  final List<ASTNode> children;
  final int position;

  const ASTNode({
    required this.type,
    required this.value,
    this.children = const [],
    this.position = 0,
  });

  @override
  String toString() =>
      'ASTNode($type, "$value", children: ${children.length})';
}

// =============================================================================
// محلل التركيب النحوي (Parser)
// =============================================================================

/// يحول قائمة الرموز إلى شجرة بناء مجردة (AST).
class FormulaParser {
  List<Token> _tokens = [];
  int _pos = 0;

  /// يحلل [formula] (بدون علامة =) ويعيد جذر AST.
  ASTNode parse(String formula) {
    final lexer = FormulaLexer(formula.toUpperCase());
    _tokens = lexer.tokenize();
    _pos = 0;

    try {
      return _parseExpression();
    } catch (_) {
      return ASTNode(type: NodeType.error, value: '#VALUE!');
    }
  }

  // الأولوية: + و - (الأقل)
  ASTNode _parseExpression() {
    var left = _parseTerm();

    while (_pos < _tokens.length) {
      final token = _tokens[_pos];
      if (token.type == TokenType.operator && '+-'.contains(token.value)) {
        _pos++;
        final right = _parseTerm();
        left = ASTNode(
          type: NodeType.binaryOp,
          value: token.value,
          children: [left, right],
          position: token.position,
        );
      } else {
        break;
      }
    }

    return left;
  }

  // الأولوية: * و / و % و ^ (أعلى)
  ASTNode _parseTerm() {
    var left = _parseFactor();

    while (_pos < _tokens.length) {
      final token = _tokens[_pos];
      if (token.type == TokenType.operator && '*/%^'.contains(token.value)) {
        _pos++;
        final right = _parseFactor();
        left = ASTNode(
          type: NodeType.binaryOp,
          value: token.value,
          children: [left, right],
          position: token.position,
        );
      } else {
        break;
      }
    }

    return left;
  }

  // الأصغر: أرقام، نصوص، مراجع، دوال، أقواس، عوامل أحادية
  ASTNode _parseFactor() {
    if (_pos >= _tokens.length) {
      return ASTNode(type: NodeType.error, value: '#VALUE!');
    }

    final token = _tokens[_pos];

    // رقم
    if (token.type == TokenType.number) {
      _pos++;
      return ASTNode(
          type: NodeType.number, value: token.value, position: token.position);
    }

    // نص
    if (token.type == TokenType.string) {
      _pos++;
      return ASTNode(
          type: NodeType.string, value: token.value, position: token.position);
    }

    // دالة
    if (token.type == TokenType.function) {
      return _parseFunction();
    }

    // مرجع خلية (وربما نطاق)
    if (token.type == TokenType.cellRef) {
      _pos++;
      if (_pos < _tokens.length &&
          _tokens[_pos].type == TokenType.rangeRef) {
        _pos++; // تخطي ':'
        if (_pos < _tokens.length &&
            _tokens[_pos].type == TokenType.cellRef) {
          final endRef = _tokens[_pos];
          _pos++;
          return ASTNode(
            type: NodeType.rangeRef,
            value: '${token.value}:${endRef.value}',
            position: token.position,
          );
        }
      }
      return ASTNode(
          type: NodeType.cellRef, value: token.value, position: token.position);
    }

    // قوس أيسر: تعبير بداخل أقواس
    if (token.type == TokenType.leftParen) {
      _pos++;
      final expr = _parseExpression();
      if (_pos < _tokens.length &&
          _tokens[_pos].type == TokenType.rightParen) {
        _pos++;
      }
      return expr;
    }

    // عامل أحادي (مثل -5)
    if (token.type == TokenType.operator && token.value == '-') {
      _pos++;
      final operand = _parseFactor();
      return ASTNode(
        type: NodeType.unaryOp,
        value: '-',
        children: [operand],
        position: token.position,
      );
    }

    // خطأ
    _pos++;
    return ASTNode(type: NodeType.error, value: '#VALUE!');
  }

  /// يحلل دالة ووسائطها.
  ASTNode _parseFunction() {
    final token = _tokens[_pos];
    _pos++; // تخطي اسم الدالة

    final args = <ASTNode>[];

    // تخطي القوس الأيسر إن وجد
    if (_pos < _tokens.length && _tokens[_pos].type == TokenType.leftParen) {
      _pos++;
    }

    // قراءة الوسائط
    while (_pos < _tokens.length &&
        _tokens[_pos].type != TokenType.rightParen) {
      args.add(_parseExpression());
      if (_pos < _tokens.length && _tokens[_pos].type == TokenType.comma) {
        _pos++;
      }
    }

    // تخطي القوس الأيمن
    if (_pos < _tokens.length && _tokens[_pos].type == TokenType.rightParen) {
      _pos++;
    }

    return ASTNode(
      type: NodeType.function,
      value: token.value,
      children: args,
      position: token.position,
    );
  }
}

// =============================================================================
// مقيم الصيغ (Evaluator) مع كشف الاعتماد الدوري
// =============================================================================

/// أسماء أخطاء الصيغ المعيارية.
class FormulaErrors {
  static const String circularRef = '#REF!'; // اعتماد دائري
  static const String divZero = '#DIV/0!'; // قسمة على صفر
  static const String value = '#VALUE!'; // قيمة غير صالحة
  static const String name = '#NAME?'; // دالة غير معروفة
  static const String num = '#NUM!'; // خطأ عددي
}

/// يقوم بتقييم شجرة AST إلى قيمة رقمية أو نصية.
///
/// يدعم كشف الاعتماد الدوري عبر [visiting]: مجموعة من مراجع الخلايا
/// التي يتم تقييمها حالياً في سلسلة الاستدعاءات.
class FormulaEvaluator {
  /// دالة لجلب قيمة خلية من مرجع (مثل A1).
  final dynamic Function(String cellRef, Set<String> visiting)? getCellValue;

  /// دالة لجلب نطاق خلايا (مثل A1:B5).
  final List<List<dynamic>> Function(
      String rangeRef, Set<String> visiting)? getRangeValue;

  FormulaEvaluator({this.getCellValue, this.getRangeValue});

  /// يقيم صيغة كاملة (بدون علامة =) ويعيد النتيجة.
  dynamic evaluate(String formula) {
    final parser = FormulaParser();
    final ast = parser.parse(formula);
    final visiting = <String>{};
    return _evaluateNode(ast, visiting);
  }

  /// يقيم عقدة مع تتبع مجموعة [visiting] لكشف الاعتماد الدوري.
  dynamic _evaluateNode(ASTNode node, Set<String> visiting) {
    switch (node.type) {
      case NodeType.number:
        return double.parse(node.value);

      case NodeType.string:
        // إزالة علامات الاقتباس
        return node.value.substring(1, node.value.length - 1);

      case NodeType.cellRef:
        if (getCellValue != null) {
          return getCellValue!(node.value, visiting);
        }
        return 0;

      case NodeType.rangeRef:
        if (getRangeValue != null) {
          return getRangeValue!(node.value, visiting);
        }
        return <List<dynamic>>[];

      case NodeType.unaryOp:
        final operand = _evaluateNode(node.children[0], visiting);
        if (operand is num) {
          return -operand;
        }
        return FormulaErrors.value;

      case NodeType.binaryOp:
        final left = _evaluateNode(node.children[0], visiting);
        final right = _evaluateNode(node.children[1], visiting);
        return _applyOperator(node.value, left, right);

      case NodeType.function:
        return _evaluateFunction(node.value, node.children, visiting);

      case NodeType.error:
        return FormulaErrors.value;
    }
  }

  /// تطبيق عامل ثنائي على المعاملين.
  dynamic _applyOperator(String op, dynamic left, dynamic right) {
    final l = _toNumber(left);
    final r = _toNumber(right);

    if (l == null || r == null) {
      if (op == '+') return '$left$right'; // دمج نصوص
      return FormulaErrors.value;
    }

    switch (op) {
      case '+':
        return l + r;
      case '-':
        return l - r;
      case '*':
        return l * r;
      case '/':
        if (r == 0) return FormulaErrors.divZero;
        return l / r;
      case '%':
        return l % r;
      case '^':
        return pow(l, r);
      case '=':
        return l == r;
      case '>':
        return l > r;
      case '<':
        return l < r;
      case '>=':
        return l >= r;
      case '<=':
        return l <= r;
      case '<>':
        return l != r;
      default:
        return FormulaErrors.value;
    }
  }

  /// تقييم دالة مع وسائطها.
  dynamic _evaluateFunction(
      String name, List<ASTNode> args, Set<String> visiting) {
    final evalArgs = args.map((a) {
      if (a.type == NodeType.rangeRef) {
        if (getRangeValue != null) {
          return getRangeValue!(a.value, visiting);
        }
        return <dynamic>[];
      }
      return _evaluateNode(a, visiting);
    }).toList();

    switch (name) {
      case 'SUM':
        return _sum(evalArgs);
      case 'AVERAGE':
      case 'AVG':
        return _average(evalArgs);
      case 'COUNT':
        return _count(evalArgs);
      case 'MIN':
        return _min(evalArgs);
      case 'MAX':
        return _max(evalArgs);
      case 'IF':
        return _if(evalArgs);
      case 'CONCATENATE':
      case 'CONCAT':
        return _concat(evalArgs);
      case 'ROUND':
        return _round(evalArgs);
      case 'ABS':
        return _abs(evalArgs);
      case 'SQRT':
        return _sqrt(evalArgs);
      case 'POWER':
        return _power(evalArgs);
      case 'NOW':
        return DateTime.now().toString();
      case 'TODAY':
        final now = DateTime.now();
        return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      default:
        return FormulaErrors.name;
    }
  }

  // ===========================================================================
  // تطبيقات الدوال
  // ===========================================================================

  dynamic _sum(List<dynamic> args) {
    double sum = 0;
    for (final arg in args) {
      _flattenAndTraverse(arg, (v) {
        final n = _toNumber(v);
        if (n != null) sum += n;
      });
    }
    return sum;
  }

  dynamic _average(List<dynamic> args) {
    double sum = 0;
    int count = 0;
    for (final arg in args) {
      _flattenAndTraverse(arg, (v) {
        final n = _toNumber(v);
        if (n != null) {
          sum += n;
          count++;
        }
      });
    }
    return count == 0 ? 0 : sum / count;
  }

  dynamic _count(List<dynamic> args) {
    int count = 0;
    for (final arg in args) {
      _flattenAndTraverse(arg, (v) {
        if (_toNumber(v) != null) count++;
      });
    }
    return count;
  }

  dynamic _min(List<dynamic> args) {
    double? minVal;
    _flattenAll(args, (v) {
      final n = _toNumber(v);
      if (n != null && (minVal == null || n < minVal)) minVal = n;
    });
    return minVal ?? 0;
  }

  dynamic _max(List<dynamic> args) {
    double? maxVal;
    _flattenAll(args, (v) {
      final n = _toNumber(v);
      if (n != null && (maxVal == null || n > maxVal)) maxVal = n;
    });
    return maxVal ?? 0;
  }

  dynamic _if(List<dynamic> args) {
    if (args.length < 3) return FormulaErrors.value;
    final cond = args[0];
    final trueVal = args[1];
    final falseVal = args[2];

    if (cond is bool) return cond ? trueVal : falseVal;
    if (cond is num) return cond != 0 ? trueVal : falseVal;
    if (cond is String && cond.isNotEmpty) return trueVal;
    return falseVal;
  }

  dynamic _concat(List<dynamic> args) {
    final buffer = StringBuffer();
    for (final arg in args) {
      _flattenAndTraverse(arg, (v) => buffer.write(v.toString()));
    }
    return buffer.toString();
  }

  dynamic _round(List<dynamic> args) {
    if (args.isEmpty) return FormulaErrors.value;
    final n = _toNumber(args[0]);
    if (n == null) return FormulaErrors.value;
    final decimals =
        args.length > 1 ? (_toNumber(args[1]) ?? 0).toInt() : 0;
    final factor = pow(10, decimals);
    return (n * factor).roundToDouble() / factor;
  }

  dynamic _abs(List<dynamic> args) {
    if (args.isEmpty) return FormulaErrors.value;
    final n = _toNumber(args[0]);
    if (n == null) return FormulaErrors.value;
    return n.abs();
  }

  dynamic _sqrt(List<dynamic> args) {
    if (args.isEmpty) return FormulaErrors.value;
    final n = _toNumber(args[0]);
    if (n == null || n < 0) return FormulaErrors.num;
    return sqrt(n);
  }

  dynamic _power(List<dynamic> args) {
    if (args.length < 2) return FormulaErrors.value;
    final base = _toNumber(args[0]);
    final exp = _toNumber(args[1]);
    if (base == null || exp == null) return FormulaErrors.value;
    return pow(base, exp);
  }

  // ===========================================================================
  // دوال مساعدة
  // ===========================================================================

  /// يحاول تحويل قيمة إلى رقم، يعيد null إذا فشل.
  double? _toNumber(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      if (value.startsWith('"') && value.endsWith('"')) {
        value = value.substring(1, value.length - 1);
      }
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
      // محاولة معالجة الأرقام العربية
      final clean = value.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(clean);
    }
    return null;
  }

  /// يطبق دالة [fn] على قيمة مفردة أو على كل قيمة داخل قائمة متداخلة.
  void _flattenAndTraverse(dynamic value, void Function(dynamic) fn) {
    if (value is List) {
      for (final item in value) {
        _flattenAndTraverse(item, fn);
      }
    } else {
      fn(value);
    }
  }

  /// يطبق دالة [fn] على كل قيمة في قائمة من الوسائط (قد تحتوي على قوائم متداخلة).
  void _flattenAll(List<dynamic> args, void Function(dynamic) fn) {
    for (final arg in args) {
      _flattenAndTraverse(arg, fn);
    }
  }
}
