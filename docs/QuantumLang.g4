grammar QuantumLang;

/*
 * QuantumLang implemented-core ANTLR4 grammar.
 *
 * This grammar intentionally follows the compiler in src/ql/ rather than the
 * longer-term language sketch. Keep docs/language.md for design direction and
 * this file for parser tooling.
 */

program
    : topLevelItem* EOF
    ;

topLevelItem
    : functionDecl
    | importDecl
    | typeDecl
    | bindingDecl
    | expression
    ;

importDecl
    : IMPORT STRING
    ;

functionDecl
    : FN IDENT LPAREN parameterList? RPAREN (ARROW typeRef)? block
    ;

parameterList
    : parameter (COMMA parameter)*
    ;

parameter
    : IDENT (DCOLON typeRef)?
    ;

bindingDecl
    : (LET | MUT | CONST) IDENT (DCOLON typeRef)? (ASSIGN expression)?
    ;

typeRef
    : IDENT
    ;

typeDecl
    : TYPE IDENT (recordBody | enumBody)
    ;

recordBody
    : LBRACE fieldDecl* RBRACE
    ;

enumBody
    : ASSIGN BIT_OR? IDENT (BIT_OR IDENT)*
    ;

fieldDecl
    : IDENT DCOLON typeRef COMMA?
    ;

block
    : LBRACE statement* RBRACE
    ;

statement
    : bindingDecl SEMI?
    | returnStmt SEMI?
    | breakStmt SEMI?
    | continueStmt SEMI?
    | expression SEMI?
    ;

returnStmt
    : RETURN expression?
    ;

breakStmt
    : BREAK
    ;

continueStmt
    : CONTINUE
    ;

expression
    : pipeExpr
    ;

pipeExpr
    : assignmentExpr (PIPE pipeExpr)?
    ;

assignmentExpr
    : logicalOrExpr (assignmentOperator assignmentExpr)?
    ;

assignmentOperator
    : ASSIGN | PLUS_ASSIGN | MINUS_ASSIGN | STAR_ASSIGN | DIV_ASSIGN | MOD_ASSIGN
    ;

logicalOrExpr
    : logicalAndExpr (OR logicalAndExpr)*
    ;

logicalAndExpr
    : comparisonExpr (AND comparisonExpr)*
    ;

comparisonExpr
    : bitwiseOrExpr (comparisonOperator bitwiseOrExpr)*
    ;

comparisonOperator
    : EQ | NEQ | LT | GT | LE | GE
    ;

bitwiseOrExpr
    : bitwiseXorExpr (BIT_OR bitwiseXorExpr)*
    ;

bitwiseXorExpr
    : bitwiseAndExpr (BIT_XOR bitwiseAndExpr)*
    ;

bitwiseAndExpr
    : shiftExpr (BIT_AND shiftExpr)*
    ;

shiftExpr
    : addExpr ((SHL | SHR) addExpr)*
    ;

addExpr
    : mulExpr ((PLUS | MINUS) mulExpr)*
    ;

mulExpr
    : unaryExpr ((STAR | DIV | MOD) unaryExpr)*
    ;

unaryExpr
    : (MINUS | BANG | NOT | TILDE) unaryExpr
    | postfixExpr
    ;

postfixExpr
    : primaryExpr postfixOperator*
    ;

postfixOperator
    : LPAREN argumentList? RPAREN
    | DOT IDENT
    | LBRACK expression RBRACK
    ;

argumentList
    : expression (COMMA expression)*
    ;

primaryExpr
    : literal
    | arrayLiteral
    | structLiteral
    | qualifiedIdent
    | LPAREN expression RPAREN
    | block
    | ifExpr
    | whileExpr
    | forExpr
    | caseExpr
    | returnStmt
    | breakStmt
    | continueStmt
    ;

arrayLiteral
    : LBRACK (expression (COMMA expression)* COMMA?)? RBRACK
    ;

structLiteral
    : qualifiedIdent LBRACE (structField (COMMA structField)* COMMA?)? RBRACE
    ;

qualifiedIdent
    : IDENT (DCOLON IDENT)*
    ;

structField
    : IDENT COLON expression
    ;

ifExpr
    : IF expression block (ELSE (ifExpr | block))?
    ;

whileExpr
    : WHILE expression block
    ;

forExpr
    : FOR IDENT IN expression RANGE expression block
    ;

caseExpr
    : CASE expression LBRACE caseArm* RBRACE
    ;

caseArm
    : BIT_OR? pattern (IF expression)? FAT_ARROW expression
    ;

pattern
    : INT
    | IDENT
    | UNDERSCORE
    ;

literal
    : INT
    | STRING
    | CHAR
    | TRUE
    | FALSE
    | NIL
    ;

FN: 'fn';
LET: 'let';
MUT: 'mut';
CONST: 'const';
IF: 'if';
ELSE: 'else';
CASE: 'case';
FOR: 'for';
WHILE: 'while';
IN: 'in';
RETURN: 'return';
BREAK: 'break';
CONTINUE: 'continue';
IMPORT: 'import';
TYPE: 'type';
TRUE: 'true';
FALSE: 'false';
NIL: 'nil';
AND: 'and';
OR: 'or';
NOT: 'not';

ARROW: '->';
FAT_ARROW: '=>';
PIPE: '|>';
RANGE: '..';
DCOLON: '::';
COLON: ':';
EQ: '==';
NEQ: '!=';
LE: '<=';
GE: '>=';
SHL: '<<';
SHR: '>>';
PLUS_ASSIGN: '+=';
MINUS_ASSIGN: '-=';
STAR_ASSIGN: '*=';
DIV_ASSIGN: '/=';
MOD_ASSIGN: '%=';
ASSIGN: '=';
LT: '<';
GT: '>';
PLUS: '+';
MINUS: '-';
STAR: '*';
DIV: '/';
MOD: '%';
BIT_OR: '|';
BIT_XOR: '^';
BIT_AND: '&';
BANG: '!';
TILDE: '~';
DOT: '.';
COMMA: ',';
SEMI: ';';
LPAREN: '(';
RPAREN: ')';
LBRACE: '{';
RBRACE: '}';
LBRACK: '[';
RBRACK: ']';
UNDERSCORE: '_';

INT
    : '0x' [0-9a-fA-F]+
    | '0o' [0-7]+
    | '0b' [01]+
    | [0-9]+
    ;

STRING
    : '"' (ESC | ~["\\\r\n])* '"'
    ;

CHAR
    : '\'' (ESC | ~['\\\r\n]) '\''
    ;

IDENT
    : [a-zA-Z_] [a-zA-Z_0-9]*
    ;

fragment ESC
    : '\\' [nt0"'\\]
    ;

LINE_COMMENT
    : '//' ~[\r\n]* -> skip
    ;

BLOCK_COMMENT
    : '/*' .*? '*/' -> skip
    ;

WS
    : [ \t\r\n]+ -> skip
    ;
