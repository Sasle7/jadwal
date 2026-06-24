import 'dart:math';

/// أنواع الرموز في الصيغة
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

/// رمز في الصيغة
class Token {
  final TokenType type;
  final String value;
  final int position;

  const Token(this.type, this.value, this.position);

  @override
  String toString() => 'Token($type, "$value")';
}

/// المحلل اللغوي للصيغ
class FormulaLexer {
  final String input;
  int _pos = 0;
  final List<Token> _tokens = [];

  FormulaLexer(this.input);

  List<Token> tokenize() {
    _tokens.clear();
    _pos = 0;

    while (_pos < input.length) {
      final ch = input[_pos];

      // مسافات
      if (ch == ' ') {
        _pos++;
        continue;
      }

      // أرقام
      if (_isDigit(ch) || (ch == '.' && _pos + 1 < input.length && _isDigit(input[_pos + 1]))) {
        _readNumber();
        continue;
      }

      // نصوص (بين علامتي اقتباس)
      if (ch == '"') {
        _readString();
        continue;
      }

      // مراجع خلايا أو دوال (حروف)
      if (_isLetter(ch) || ch == '_') {
        _readIdentifier();
        continue;
      }

      // العمليات الحسابية
      if ('+-*/^%'.contains(ch)) {
        _tokens.add(Token(TokenType.operator, ch, _pos));
        _pos++;
        continue;
      }

      // مقارنات
      if (ch == '=' && _pos > 0) {
        // هذا علامة يساوي في المقارنة وليس بداية الصيغة
        _tokens.add(Token(TokenType.operator, '=', _pos));
        _pos++;
        continue;
      }
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

      // فاصلة
      if (ch == ',') {
        _tokens.add(Token(TokenType.comma, ',', _pos));
        _pos++;
        continue;
      }

      // علامة النقطتين (نطاق)
      if (ch == ':') {
        _tokens.add(Token(TokenType.rangeRef, ':', _pos));
        _pos++;
        continue;
      }

      // علامة الدولار (مرجع مطلق)
      if (ch == '\$') {
        _pos++;
        continue;
      }

      // رمز غير معروف - نتجاوزه
      _pos++;
    }

    return _tokens;
  }

  void _readNumber() {
    final start = _pos;
    while (_pos < input.length && (_isDigit(input[_pos]) || input[_pos] == '.')) {
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
    while (_pos < input.length && (_isLetter(input[_pos]) || _isDigit(input[_pos]) || input[_pos] == '_' || input[_pos] == '.')) {
      _pos++;
    }
    final word = input.substring(start, _pos).toUpperCase();

    // التحقق إذا كانت دالة
    if (_pos < input.length && input[_pos] == '(') {
      _tokens.add(Token(TokenType.function, word, start));
    } else {
      _tokens.add(Token(TokenType.cellRef, input.substring(start, _pos), start));
    }
  }

  bool _isDigit(String ch) => ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;
  bool _isLetter(String ch) {
    final code = ch.codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }
}

/// أنواع عقد شجرة بناء الجملة (AST)
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

/// عقدة في شجرة بناء الجملة المجردة (AST)
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
  String toString() => 'ASTNode($type, "$value", children: ${children.length})';
}

/// المحلل النحوي للصيغ (من الرموز إلى شجرة AST)
class FormulaParser {
  List<Token> _tokens = [];
  int _pos = 0;

  ASTNode parse(String formula) {
    final lexer = FormulaLexer(formula.toUpperCase());
    _tokens = lexer.tokenize();
    _pos = 0;

    try {
      return _parseExpression();
    } catch (e) {
      return ASTNode(type: NodeType.error, value: '#VALUE!');
    }
  }

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

  ASTNode _parseFactor() {
    if (_pos >= _tokens.length) {
      return ASTNode(type: NodeType.error, value: '#VALUE!');
    }

    final token = _tokens[_pos];

    // رقم
    if (token.type == TokenType.number) {
      _pos++;
      return ASTNode(type: NodeType.number, value: token.value, position: token.position);
    }

    // نص
    if (token.type == TokenType.string) {
      _pos++;
      return ASTNode(type: NodeType.string, value: token.value, position: token.position);
    }

    // دالة
    if (token.type == TokenType.function) {
      return _parseFunction();
    }

    // مرجع خلية
    if (token.type == TokenType.cellRef) {
      _pos++;
      // التحقق إذا كان هناك نطاق (مثلاً A1:A10)
      if (_pos < _tokens.length && _tokens[_pos].type == TokenType.rangeRef) {
        _pos++; // تخطي النقطتين
        if (_pos < _tokens.length && _tokens[_pos].type == TokenType.cellRef) {
          final endRef = _tokens[_pos];
          _pos++;
          return ASTNode(
            type: NodeType.rangeRef,
            value: '${token.value}:${endRef.value}',
            position: token.position,
          );
        }
      }
      return ASTNode(type: NodeType.cellRef, value: token.value, position: token.position);
    }

    // قوس أيسر - تعبير داخل أقواس
    if (token.type == TokenType.leftParen) {
      _pos++;
      final expr = _parseExpression();
      if (_pos < _tokens.length && _tokens[_pos].type == TokenType.rightParen) {
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

    _pos++;
    return ASTNode(type: NodeType.error, value: '#VALUE!');
  }

  ASTNode _parseFunction() {
    final token = _tokens[_pos];
    _pos++; // تخطي اسم الدالة

    final args = <ASTNode>[];

    // تخطي القوس الأيسر
    if (_pos < _tokens.length && _tokens[_pos].type == TokenType.leftParen) {
      _pos++;
    }

    // قراءة الوسائط
    while (_pos < _tokens.length && _tokens[_pos].type != TokenType.rightParen) {
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

/// مقيم الصيغ - يقوم بحساب قيمة شجرة AST
class FormulaEvaluator {
  /// دالة للحصول على قيمة خلية من مرجع
  final dynamic Function(String cellRef)? getCellValue;
  /// دالة للحصول على نطاق خلايا
  final List<List<dynamic>> Function(String rangeRef)? getRangeValue;

  FormulaEvaluator({this.getCellValue, this.getRangeValue});

  /// تقييم صيغة كاملة (بدون علامة =)
  dynamic evaluate(String formula) {
    final parser = FormulaParser();
    final ast = parser.parse(formula);
    return _evaluateNode(ast);
  }

  dynamic _evaluateNode(ASTNode node) {
    switch (node.type) {
      case NodeType.number:
        return double.parse(node.value);

      case NodeType.string:
        return node.value.substring(1, node.value.length - 1); // إزالة علامات الاقتباس

      case NodeType.cellRef:
        if (getCellValue != null) {
          return getCellValue!(node.value);
        }
        return 0;

      case NodeType.rangeRef:
        if (getRangeValue != null) {
          return getRangeValue!(node.value);
        }
        return 0;

      case NodeType.unaryOp:
        final operand = _evaluateNode(node.children[0]);
        if (operand is num) {
          return -operand;
        }
        throw Exception('#VALUE!');

      case NodeType.binaryOp:
        final left = _evaluateNode(node.children[0]);
        final right = _evaluateNode(node.children[1]);
        return _applyOperator(node.value, left, right);

      case NodeType.function:
        return _evaluateFunction(node.value, node.children);

      case NodeType.error:
        return '#VALUE!';
    }
  }

  dynamic _applyOperator(String op, dynamic left, dynamic right) {
    // محاولة تحويل القيم إلى أرقام
    final l = _toNumber(left);
    final r = _toNumber(right);

    if (l == null || r == null) {
      // إذا كان العامل +، نقوم بدمج النصوص
      if (op == '+') {
        return '$left$right';
      }
      return '#VALUE!';
    }

    switch (op) {
      case '+':
        return l + r;
      case '-':
        return l - r;
      case '*':
        return l * r;
      case '/':
        if (r == 0) return '#DIV/0!';
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
        return '#VALUE!';
    }
  }

  dynamic _evaluateFunction(String name, List<ASTNode> args) {
    final evalArgs = args.map((a) {
      if (a.type == NodeType.rangeRef) {
        if (getRangeValue != null) {
          return getRangeValue!(a.value);
        }
        return <dynamic>[];
      }
      return _evaluateNode(a);
    }).toList();

    switch (name) {
      case 'SUM':
        return _sumFunction(evalArgs);
      case 'AVERAGE':
      case 'AVG':
        return _averageFunction(evalArgs);
      case 'COUNT':
        return _countFunction(evalArgs);
      case 'MIN':
        return _minFunction(evalArgs);
      case 'MAX':
        return _maxFunction(evalArgs);
      case 'IF':
        return _ifFunction(evalArgs);
      case 'CONCATENATE':
      case 'CONCAT':
        return _concatenateFunction(evalArgs);
      case 'ROUND':
        return _roundFunction(evalArgs);
      case 'ABS':
        return _absFunction(evalArgs);
      case 'SQRT':
        return _sqrtFunction(evalArgs);
      case 'POWER':
        return _powerFunction(evalArgs);
      case 'NOW':
        return DateTime.now().toString();
      case 'TODAY':
        final now = DateTime.now();
        return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      default:
        return '#NAME?';
    }
  }

  dynamic _sumFunction(List<dynamic> args) {
    double sum = 0;
    for (final arg in args) {
      if (arg is List) {
        for (final row in arg) {
          if (row is List) {
            for (final cell in row) {
              final n = _toNumber(cell);
              if (n != null) sum += n;
            }
          } else {
            final n = _toNumber(row);
            if (n != null) sum += n;
          }
        }
      } else {
        final n = _toNumber(arg);
        if (n != null) sum += n;
      }
    }
    return sum;
  }

  dynamic _averageFunction(List<dynamic> args) {
    double sum = 0;
    int count = 0;
    for (final arg in args) {
      if (arg is List) {
        for (final row in arg) {
          if (row is List) {
            for (final cell in row) {
              final n = _toNumber(cell);
              if (n != null) {
                sum += n;
                count++;
              }
            }
          } else {
            final n = _toNumber(row);
            if (n != null) {
              sum += n;
              count++;
            }
          }
        }
      } else {
        final n = _toNumber(arg);
        if (n != null) {
          sum += n;
          count++;
        }
      }
    }
    return count == 0 ? 0 : sum / count;
  }

  dynamic _countFunction(List<dynamic> args) {
    int count = 0;
    for (final arg in args) {
      if (arg is List) {
        for (final row in arg) {
          if (row is List) {
            for (final cell in row) {
              if (_toNumber(cell) != null) count++;
            }
          } else {
            if (_toNumber(row) != null) count++;
          }
        }
      } else {
        if (_toNumber(arg) != null) count++;
      }
    }
    return count;
  }

  dynamic _minFunction(List<dynamic> args) {
    double? min;
    for (final arg in args) {
      if (arg is List) {
        for (final row in arg) {
          if (row is List) {
            for (final cell in row) {
              final n = _toNumber(cell);
              if (n != null && (min == null || n < min)) min = n;
            }
          } else {
            final n = _toNumber(row);
            if (n != null && (min == null || n < min)) min = n;
          }
        }
      } else {
        final n = _toNumber(arg);
        if (n != null && (min == null || n < min)) min = n;
      }
    }
    return min ?? 0;
  }

  dynamic _maxFunction(List<dynamic> args) {
    double? max;
    for (final arg in args) {
      if (arg is List) {
        for (final row in arg) {
          if (row is List) {
            for (final cell in row) {
              final n = _toNumber(cell);
              if (n != null && (max == null || n > max)) max = n;
            }
          } else {
            final n = _toNumber(row);
            if (n != null && (max == null || n > max)) max = n;
          }
        }
      } else {
        final n = _toNumber(arg);
        if (n != null && (max == null || n > max)) max = n;
      }
    }
    return max ?? 0;
  }

  dynamic _ifFunction(List<dynamic> args) {
    if (args.length < 3) return '#VALUE!';
    final condition = args[0];
    final trueVal = args[1];
    final falseVal = args[2];

    // تقييم الشرط
    if (condition is bool) {
      return condition ? _evaluateValue(trueVal) : _evaluateValue(falseVal);
    }
    if (condition is num) {
      return condition != 0 ? _evaluateValue(trueVal) : _evaluateValue(falseVal);
    }
    // إذا كان نصًا غير فارغ
    if (condition is String && condition.isNotEmpty) {
      return _evaluateValue(trueVal);
    }
    return _evaluateValue(falseVal);
  }

  dynamic _concatenateFunction(List<dynamic> args) {
    String result = '';
    for (final arg in args) {
      if (arg is List) {
        for (final row in arg) {
          if (row is List) {
            for (final cell in row) {
              result += cell.toString();
            }
          } else {
            result += row.toString();
          }
        }
      } else {
        result += arg.toString();
      }
    }
    return result;
  }

  dynamic _roundFunction(List<dynamic> args) {
    if (args.isEmpty) return '#VALUE!';
    final n = _toNumber(args[0]);
    if (n == null) return '#VALUE!';
    final decimals = args.length > 1 ? (_toNumber(args[1]) ?? 0).toInt() : 0;
    final factor = pow(10, decimals);
    return (n * factor).roundToDouble() / factor;
  }

  dynamic _absFunction(List<dynamic> args) {
    if (args.isEmpty) return '#VALUE!';
    final n = _toNumber(args[0]);
    if (n == null) return '#VALUE!';
    return n.abs();
  }

  dynamic _sqrtFunction(List<dynamic> args) {
    if (args.isEmpty) return '#VALUE!';
    final n = _toNumber(args[0]);
    if (n == null || n < 0) return '#NUM!';
    return sqrt(n);
  }

  dynamic _powerFunction(List<dynamic> args) {
    if (args.length < 2) return '#VALUE!';
    final base = _toNumber(args[0]);
    final exp = _toNumber(args[1]);
    if (base == null || exp == null) return '#VALUE!';
    return pow(base, exp);
  }

  dynamic _evaluateValue(dynamic val) {
    if (val is ASTNode) {
      return _evaluateNode(val);
    }
    return val;
  }

  double? _toNumber(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      // إزالة علامات الاقتباس
      if (value.startsWith('"') && value.endsWith('"')) {
        value = value.substring(1, value.length - 1);
      }
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
      // محاولة تحويل النص العربي إلى أرقام
      final arabicDigits = value.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(arabicDigits);
    }
    return null;
  }
}
