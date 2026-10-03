import 'exceptions.dart';
import 'expression.dart';
import 'lexer.dart';
import 'qname.dart';

/// Parses an XPath expression.
///
/// Port of `XPathParseTool.parseXPath`. Throws [XPathSyntaxException] for
/// invalid input, including the empty string.
XPathExpression parseXPath(String xpath) => _Parser.parse(lex(xpath));

/// Port of `org.javarosa.xpath.parser.Parser`.
///
/// JavaRosa does not use a grammar-driven parser. It starts with one flat
/// list of tokens and repeatedly *condenses* runs of it into tree nodes:
/// function calls, then parentheses, predicates, operators by precedence,
/// and finally path expressions. The steps below follow it one to one, so
/// associativity, precedence quirks (for example `8|-9` is rejected) and
/// error messages are identical.
abstract final class _Parser {
  static XPathExpression parse(List<Token> tokens) {
    final root = _AbstractExpr([...tokens]);
    _parseFuncCalls(root);
    _parseBalanced(root, (node) => node, TokenType.lparen, TokenType.rparen);
    _parseBalanced(root, _Predicate.new, TokenType.lbrack, TokenType.rbrack);
    _parseOperators(root);
    _parsePathExpr(root);
    _verifyBaseExpr(root);
    return root.build();
  }

  static void _parseOperators(_Node root) {
    _parseBinaryOp(root, const {TokenType.or}, rightAssociative: true);
    _parseBinaryOp(root, const {TokenType.and}, rightAssociative: true);
    _parseBinaryOp(root, const {TokenType.eq, TokenType.neq});
    _parseBinaryOp(root, const {
      TokenType.lt,
      TokenType.lte,
      TokenType.gt,
      TokenType.gte,
    });
    _parseBinaryOp(root, const {TokenType.plus, TokenType.minus});
    _parseBinaryOp(root, const {TokenType.mult, TokenType.div, TokenType.mod});
    _parseUnaryMinus(root);
    // 'a|-b' doesn't parse; JavaRosa considers that correct.
    _parseBinaryOp(root, const {TokenType.union});
  }

  static void _parseFuncCalls(_Node node) {
    if (node is _AbstractExpr) {
      var i = 0;
      while (i < node.content.length - 1) {
        if (node.tokenTypeAt(i + 1) == TokenType.lparen &&
            node.tokenTypeAt(i) == TokenType.qname) {
          _condenseFuncCall(node, i);
        }
        i++;
      }
    }
    for (final child in node.children) {
      _parseFuncCalls(child);
    }
  }

  static void _condenseFuncCall(_AbstractExpr node, int funcStart) {
    final call = _FunctionCall(node.tokenAt(funcStart)!.value! as XPathQName);
    final funcEnd = node.indexOfBalanced(
      funcStart + 1,
      TokenType.rparen,
      TokenType.lparen,
      TokenType.rparen,
    );
    if (funcEnd == -1) {
      throw const XPathSyntaxException('Mismatched brackets or parentheses');
    }
    final args = node.partitionBalanced(
      TokenType.comma,
      funcStart + 1,
      TokenType.lparen,
      TokenType.rparen,
    )!;
    final noArgs =
        args.pieces.length == 1 &&
        (args.pieces.first as _AbstractExpr).content.isEmpty;
    if (!noArgs) call.args.addAll(args.pieces);
    node.condense(call, funcStart, funcEnd + 1);
  }

  static void _parseBalanced(
    _Node node,
    _Node Function(_AbstractExpr) newNode,
    TokenType left,
    TokenType right,
  ) {
    if (node is _AbstractExpr) {
      var i = 0;
      while (i < node.content.length) {
        final type = node.tokenTypeAt(i);
        if (type == right) {
          throw const XPathSyntaxException(
            'Unbalanced brackets or parentheses!',
          );
        } else if (type == left) {
          final j = node.indexOfBalanced(i, right, left, right);
          if (j == -1) {
            throw const XPathSyntaxException(
              'mismatched brackets or parentheses!',
            );
          }
          node.condense(newNode(node.extract(i + 1, j)), i, j + 1);
        }
        i++;
      }
    }
    for (final child in node.children) {
      _parseBalanced(child, newNode, left, right);
    }
  }

  static void _parseBinaryOp(
    _Node node,
    Set<TokenType> ops, {
    bool rightAssociative = false,
  }) {
    if (node is _AbstractExpr) {
      final part = node.partition(ops, 0, node.content.length);
      if (part.separators.isNotEmpty) {
        node.condense(
          _BinaryOp(part.pieces, part.separators, rightAssociative),
          0,
          node.content.length,
        );
      }
    }
    for (final child in node.children) {
      _parseBinaryOp(child, ops, rightAssociative: rightAssociative);
    }
  }

  static void _parseUnaryMinus(_Node node) {
    if (node is _AbstractExpr &&
        node.content.isNotEmpty &&
        node.tokenTypeAt(0) == TokenType.uminus) {
      final operand = node.content.length > 1
          ? node.extract(1, node.content.length)
          : _AbstractExpr([]);
      node.condense(_UnaryMinus(operand), 0, node.content.length);
    }
    for (final child in node.children) {
      _parseUnaryMinus(child);
    }
  }

  static void _parsePathExpr(_Node node) {
    if (node is _AbstractExpr) {
      final part = node.partition(
        const {TokenType.slash, TokenType.dblSlash},
        0,
        node.content.length,
      );
      if (part.separators.isEmpty) {
        if (_isStep(node)) {
          final path = _LocPath()..clauses.add(_parseStep(node));
          node.condense(path, 0, node.content.length);
        } else {
          final filter = _parseFilterExpr(node);
          if (filter != null) node.condense(filter, 0, node.content.length);
        }
      } else {
        final path = _LocPath()..separators.addAll(part.separators);
        final isRootOnly =
            part.separators.length == 1 &&
            node.content.length == 1 &&
            part.separators.first == TokenType.slash;
        if (!isRootOnly) {
          for (var i = 0; i < part.pieces.length; i++) {
            final piece = part.pieces[i] as _AbstractExpr;
            if (_isStep(piece)) {
              path.clauses.add(_parseStep(piece));
            } else if (i == 0) {
              if (piece.content.isNotEmpty) {
                path.clauses.add(_parseFilterExpr(piece) ?? piece);
              }
            } else {
              throw const XPathSyntaxException('Unexpected beginning of path');
            }
          }
        }
        node.condense(path, 0, node.content.length);
      }
    }
    for (final child in node.children) {
      _parsePathExpr(child);
    }
  }

  static const _nodeTypeTests = {
    'node',
    'text',
    'comment',
    'processing-instruction',
  };

  static bool _isStep(_AbstractExpr node) {
    if (node.content.isEmpty) return false;
    final first = node.content.first;
    if (first is _FunctionCall) {
      return _nodeTypeTests.contains(first.name.toString());
    }
    return const {
      TokenType.qname,
      TokenType.wildcard,
      TokenType.nsWildcard,
      TokenType.at,
      TokenType.dot,
      TokenType.dblDot,
    }.contains(node.tokenTypeAt(0));
  }

  static _PathStep _parseStep(_AbstractExpr node) {
    final content = node.content;
    if (content.length == 1 && node.tokenTypeAt(0) == TokenType.dot) {
      return _PathStep.self();
    }
    if (content.length == 1 && node.tokenTypeAt(0) == TokenType.dblDot) {
      return _PathStep.parent();
    }

    var i = 0;
    XPathAxis? axis; // null: no axis given (child), set: explicit or '@'
    if (content.isNotEmpty && node.tokenTypeAt(0) == TokenType.at) {
      axis = XPathAxis.attribute;
      i += 1;
    } else if (content.length > 1 &&
        node.tokenTypeAt(0) == TokenType.qname &&
        node.tokenTypeAt(1) == TokenType.dblColon) {
      final axisName = node.tokenAt(0)!.value.toString();
      axis = XPathAxis.fromName(axisName);
      if (axis == null) {
        throw XPathSyntaxException('Invalid Axis: $axisName');
      }
      i += 2;
    }

    final step = _PathStep(axis ?? XPathAxis.child);
    final type = content.length > i ? node.tokenTypeAt(i) : null;
    final item = content.length > i ? content[i] : null;
    if (type == TokenType.wildcard) {
      step.test = StepTest.nameWildcard;
    } else if (type == TokenType.nsWildcard) {
      step
        ..test = StepTest.namespaceWildcard
        ..namespace = node.tokenAt(i)!.value! as String;
    } else if (type == TokenType.qname) {
      step
        ..test = StepTest.name
        ..name = node.tokenAt(i)!.value! as XPathQName;
    } else if (item is _FunctionCall) {
      if (!_isValidNodeTypeTest(item)) throw const XPathSyntaxException();
      step.typeTest = item;
    } else {
      throw const XPathSyntaxException();
    }
    i += 1;
    for (; i < content.length; i++) {
      final predicate = content[i];
      if (predicate is! _Predicate) throw const XPathSyntaxException();
      step.predicates.add(predicate);
    }
    return step;
  }

  static bool _isValidNodeTypeTest(_FunctionCall f) {
    final name = f.name.toString();
    if (!_nodeTypeTests.contains(name)) return false;
    if (f.args.isEmpty) return true;
    if (name == 'processing-instruction' && f.args.length == 1) {
      final arg = f.args.first as _AbstractExpr;
      return arg.content.length == 1 && arg.tokenTypeAt(0) == TokenType.str;
    }
    return false;
  }

  static _FilterExpr? _parseFilterExpr(_AbstractExpr node) {
    final predicates = <_Node>[];
    var i = node.content.length - 1;
    for (; i >= 0; i--) {
      final item = node.content[i];
      if (item is! _Predicate) break;
      predicates.insert(0, item);
    }
    if (predicates.isEmpty) return null;
    return _FilterExpr(node.extract(0, i + 1), predicates);
  }

  static void _verifyBaseExpr(_Node node) {
    if (node is _AbstractExpr && !node.isNormalized) {
      throw XPathSyntaxException('Bad node: $node');
    }
    for (final child in node.children) {
      _verifyBaseExpr(child);
    }
  }
}

// ---------------------------------------------------------------------------
// Intermediate parse tree (port of org.javarosa.xpath.parser.ast).
// ---------------------------------------------------------------------------

sealed class _Node {
  List<_Node> get children;
  XPathExpression build();
}

/// A run of tokens and already-condensed nodes.
final class _AbstractExpr extends _Node {
  _AbstractExpr(this.content);

  /// Mixture of [Token]s and [_Node]s.
  final List<Object> content;

  @override
  List<_Node> get children => content.whereType<_Node>().toList();

  @override
  XPathExpression build() {
    if (content.length != 1) throw const XPathSyntaxException();
    final item = content.first;
    if (item is _Node) return item.build();
    final token = item as Token;
    return switch (token.type) {
      TokenType.num => XPathNumericLiteral(token.value! as double),
      TokenType.str => XPathStringLiteral(token.value! as String),
      TokenType.variable => XPathVariableReference(token.value! as XPathQName),
      _ => throw const XPathSyntaxException(),
    };
  }

  bool get isTerminal =>
      content.length == 1 &&
      const {
        TokenType.num,
        TokenType.str,
        TokenType.variable,
      }.contains(tokenTypeAt(0));

  bool get isNormalized {
    if (content.length == 1 && content.first is _Node) {
      final child = content.first;
      if (child is _PathStep || child is _Predicate) {
        throw StateError("shouldn't happen");
      }
      return true;
    }
    return isTerminal;
  }

  Token? tokenAt(int i) {
    final item = content[i];
    return item is Token ? item : null;
  }

  TokenType? tokenTypeAt(int i) => tokenAt(i)?.type;

  _AbstractExpr extract(int start, int end) =>
      _AbstractExpr(content.sublist(start, end));

  void condense(_Node node, int start, int end) {
    content.replaceRange(start, end, [node]);
  }

  int indexOfBalanced(
    int start,
    TokenType target,
    TokenType leftPush,
    TokenType rightPop,
  ) {
    var depth = 0;
    var i = start + 1;
    while (depth >= 0 && i < content.length) {
      final type = tokenTypeAt(i);
      if (depth == 0 && type == target) return i;
      if (type == leftPush) {
        depth++;
      } else if (type == rightPop) {
        depth--;
      }
      i++;
    }
    return -1;
  }

  _Partition partition(Set<TokenType> separators, int start, int end) {
    final part = _Partition();
    final separatorIndexes = <int>[];
    for (var i = start; i < end; i++) {
      final type = tokenTypeAt(i);
      if (type != null && separators.contains(type)) {
        part.separators.add(type);
        separatorIndexes.add(i);
      }
    }
    for (var i = 0; i <= separatorIndexes.length; i++) {
      final pieceStart = i == 0 ? start : separatorIndexes[i - 1] + 1;
      final pieceEnd = i == separatorIndexes.length ? end : separatorIndexes[i];
      part.pieces.add(extract(pieceStart, pieceEnd));
    }
    return part;
  }

  _Partition? partitionBalanced(
    TokenType separator,
    int start,
    TokenType leftPush,
    TokenType rightPop,
  ) {
    final end = indexOfBalanced(start, rightPop, leftPush, rightPop);
    if (end == -1) return null;
    final part = _Partition();
    final separatorIndexes = <int>[];
    var k = start;
    while (true) {
      k = indexOfBalanced(k, separator, leftPush, rightPop);
      if (k == -1) break;
      separatorIndexes.add(k);
      part.separators.add(separator);
    }
    for (var i = 0; i <= separatorIndexes.length; i++) {
      final pieceStart = i == 0 ? start + 1 : separatorIndexes[i - 1] + 1;
      final pieceEnd = i == separatorIndexes.length ? end : separatorIndexes[i];
      part.pieces.add(extract(pieceStart, pieceEnd));
    }
    return part;
  }

  @override
  String toString() => 'abstractexpr {${content.join(' ')}}';
}

final class _Partition {
  final pieces = <_Node>[];
  final separators = <TokenType>[];
}

final class _BinaryOp extends _Node {
  _BinaryOp(this.exprs, this.ops, this.rightAssociative);

  final List<_Node> exprs;
  final List<TokenType> ops;
  final bool rightAssociative;

  @override
  List<_Node> get children => exprs;

  @override
  XPathExpression build() {
    if (!rightAssociative) {
      var x = exprs.first.build();
      for (var i = 1; i < exprs.length; i++) {
        x = _binary(ops[i - 1], x, exprs[i].build());
      }
      return x;
    }
    var x = exprs.last.build();
    for (var i = exprs.length - 2; i >= 0; i--) {
      x = _binary(ops[i], exprs[i].build(), x);
    }
    return x;
  }

  static XPathExpression _binary(
    TokenType op,
    XPathExpression a,
    XPathExpression b,
  ) => switch (op) {
    TokenType.or => XPathBoolExpr(BoolOp.or, a, b),
    TokenType.and => XPathBoolExpr(BoolOp.and, a, b),
    TokenType.eq => XPathEqExpr(true, a, b),
    TokenType.neq => XPathEqExpr(false, a, b),
    TokenType.lt => XPathCmpExpr(CmpOp.lt, a, b),
    TokenType.lte => XPathCmpExpr(CmpOp.lte, a, b),
    TokenType.gt => XPathCmpExpr(CmpOp.gt, a, b),
    TokenType.gte => XPathCmpExpr(CmpOp.gte, a, b),
    TokenType.plus => XPathArithExpr(ArithOp.add, a, b),
    TokenType.minus => XPathArithExpr(ArithOp.subtract, a, b),
    TokenType.mult => XPathArithExpr(ArithOp.multiply, a, b),
    TokenType.div => XPathArithExpr(ArithOp.divide, a, b),
    TokenType.mod => XPathArithExpr(ArithOp.modulo, a, b),
    TokenType.union => XPathUnionExpr(a, b),
    _ => throw const XPathSyntaxException(),
  };
}

final class _UnaryMinus extends _Node {
  _UnaryMinus(this.expr);

  final _Node expr;

  @override
  List<_Node> get children => [expr];

  @override
  XPathExpression build() => XPathNumNegExpr(expr.build());
}

final class _FunctionCall extends _Node {
  _FunctionCall(this.name);

  final XPathQName name;
  final args = <_Node>[];

  @override
  List<_Node> get children => args;

  @override
  XPathExpression build() =>
      XPathFuncExpr(name, [for (final arg in args) arg.build()]);
}

final class _Predicate extends _Node {
  _Predicate(this.expr);

  final _Node expr;

  @override
  List<_Node> get children => [expr];

  @override
  XPathExpression build() => expr.build();
}

final class _FilterExpr extends _Node {
  _FilterExpr(this.expr, this.predicates);

  final _AbstractExpr expr;
  final List<_Node> predicates;

  @override
  List<_Node> get children => [expr, ...predicates];

  @override
  XPathFilterExpr build() =>
      XPathFilterExpr(expr.build(), [for (final p in predicates) p.build()]);
}

final class _LocPath extends _Node {
  final clauses = <_Node>[];
  final separators = <TokenType>[];

  @override
  List<_Node> get children => clauses;

  bool get isAbsolute =>
      clauses.length == separators.length ||
      (clauses.isEmpty && separators.length == 1);

  @override
  XPathExpression build() {
    final steps = <XPathStep>[];
    XPathExpression? filter;
    final offset = isAbsolute ? 1 : 0;
    for (var i = 0; i < clauses.length + offset; i++) {
      if (offset == 0 || i > 0) {
        final clause = clauses[i - offset];
        if (clause is _PathStep) {
          steps.add(clause.toStep());
        } else {
          filter = clause.build();
        }
      }
      if (i < separators.length && separators[i] == TokenType.dblSlash) {
        steps.add(XPathStep.abbreviatedDescendants());
      }
    }
    if (filter == null) {
      return XPathPathExpr(
        isAbsolute ? PathStart.root : PathStart.relative,
        steps,
      );
    }
    return XPathPathExpr.fromFilter(
      filter is XPathFilterExpr ? filter : XPathFilterExpr(filter, const []),
      steps,
    );
  }
}

final class _PathStep extends _Node {
  _PathStep(this.axis);

  _PathStep.self()
    : axis = XPathAxis.self,
      _abbreviation = XPathStep.abbreviatedSelf();

  _PathStep.parent()
    : axis = XPathAxis.parent,
      _abbreviation = XPathStep.abbreviatedParent();

  final XPathAxis axis;
  XPathStep? _abbreviation;
  StepTest? test;
  XPathQName? name;
  String? namespace;
  final predicates = <_Node>[];

  set typeTest(_FunctionCall call) {
    test = switch (call.name.toString()) {
      'node' => StepTest.node,
      'text' => StepTest.text,
      'comment' => StepTest.comment,
      _ => StepTest.processingInstruction,
    };
    if (call.args.isNotEmpty) {
      _literal =
          (call.args.first as _AbstractExpr).tokenAt(0)!.value! as String;
    }
  }

  String? _literal;

  @override
  List<_Node> get children => predicates;

  @override
  XPathExpression build() =>
      throw StateError('a step is built as part of a path');

  XPathStep toStep() {
    if (_abbreviation case final abbreviation?) return abbreviation;
    final built = [for (final p in predicates) p.build()];
    return switch (test!) {
      StepTest.name => XPathStep.named(axis, name!, built),
      StepTest.namespaceWildcard => XPathStep.namespaceWildcard(
        axis,
        namespace!,
        built,
      ),
      final other => XPathStep.typed(
        axis,
        other,
        literal: _literal,
        predicates: built,
      ),
    };
  }
}
