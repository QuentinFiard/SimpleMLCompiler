(* Lexical analyser for a simple ML subset *)
{
open Parser;;
}

let digit = ['0' - '9']
let non_digit = ['a'-'z' 'A'-'Z' '_']

let blank = [' ' '\t' '\n']

let int = digit+
let identifier = non_digit (digit | non_digit)*

rule token = parse
  | int as n { INT(int_of_string n) }
  | "true" { BOOL(true) }
  | "false" { BOOL(false) }
  | "let" { LET }
  | "in" { IN }
  | "rec" { REC }
  | "fun" { FUN }
  | "->" { ARROW }
  | "==" { EQ }
  | "=" { ASSIGN }
  | "+" { PLUS }
  | "-" { MINUS }
  | "*" { TIMES }
  | "/" { DIV }
  | "&&" { AND }
  | "||" { OR }
  | "(" { LPAREN }
  | ")" { RPAREN }
  | "if" { IF }
  | "then" { THEN }
  | "else" { ELSE }
  | "!=" { NEQ }
  | "<=" { LE }
  | "<" { LT }
  | ">=" { GE }
  | ">" { GT }
  | ";" { SEMICOLON }
  | eof  { EOF }
  | blank { token lexbuf } (* ignore this token *)
  | identifier as id { ID(id) }
  | _ as c { Printf.printf "Unrecognized character: %c\n" c; raise (Failure "") }