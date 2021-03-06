open UserInterface;;

open Printf;;
open Pervasives;;

open Interpreter;;
open Types;;

open Expression;;

(* We start by opening the file to compile, whose file name was given on the command line *)
let file_path = Sys.argv.(1) in
let file = open_in file_path in

(* A convenient function to read a file and display its content *)
(* The file cursor is rewinded at the end of the read *)
let print_file f : unit =
    let rec aux_print_file f first : unit =
        try
            if(not first)
            then
                print_newline();
            print_string (input_line f);
            aux_print_file f false
        with eof ->
            () in
    aux_print_file f true;
    seek_in f 0 in
    
(* Pass 1 *)
(* We transform boolean operators into conditionnal expressions *)
(* There is no need to change the data structure at this point, the function is therefore of the type ML_syntax.expression -> ML_syntax.expression *)
(* Ml_syntax.expression is the type for raw expressions, directly obtained from the parser *)

let rec binaryBoolOpToCond = function
    | ML_syntax.Local(v,e,scope) -> ML_syntax.Local(v,binaryBoolOpToCond e,binaryBoolOpToCond scope)
    | ML_syntax.RecFun(f,arg,body,scope) ->
        ML_syntax.RecFun(f,arg,binaryBoolOpToCond body,binaryBoolOpToCond scope)
    | ML_syntax.Fun(arg,body) -> ML_syntax.Fun(arg,binaryBoolOpToCond body)
    | ML_syntax.Eval(e1,e2) -> ML_syntax.Eval(binaryBoolOpToCond e1,binaryBoolOpToCond e2)
    | ML_syntax.Binary(op,e1,e2) when op==And ->
        ML_syntax.If(binaryBoolOpToCond e1,binaryBoolOpToCond e2,ML_syntax.Const (ML_syntax.Bool false))
    | ML_syntax.Binary(op,e1,e2) when op==Or ->
        ML_syntax.If(binaryBoolOpToCond e1,ML_syntax.Const (ML_syntax.Bool true),binaryBoolOpToCond e2)
    | ML_syntax.Binary(op,e1,e2) -> ML_syntax.Binary(op,binaryBoolOpToCond e1,binaryBoolOpToCond e2)
    | ML_syntax.If(cond,e1,e2) -> ML_syntax.If(binaryBoolOpToCond cond,binaryBoolOpToCond e1,binaryBoolOpToCond e2)
    | _ as ast -> ast
    in

let pass1 = function
    | Raw e -> Raw (binaryBoolOpToCond e)
    | e -> e in
    
(* Pass 2 *)
(* Two steps :*)
(*    - We compute De Bruijn indexes for leaf variables *)
(*    - We convert the resulting expression to the type DeBruijnExpression.expression (ie we drop the names of the variables) *)
let pass2 = function
    | Raw e -> DBE (Raw2DBE.raw2dbe e)
    | e -> e
    in
    
(* Pass 3 *)
(* We check that the program is well typed using type inference provided by Hindley-Milner algorithm *)
let pass3 expr = 
    printf "Infering expression type...\n";
    let t = TypeInferer.inferType expr in
    outputType t;
    printf "\n";
    expr in
    
(* Pass 4 *)
(* We convert the program to abstract machine code *)
let pass4 = function
    | DBE e ->
        printf "Converting the program to abstract machine code...\n";
        Code (DBE2Code.dbe2code e)
    | e -> e
    in
    
(* The compilation function itself *)
(* It is formed of a first pass where we read the file, transform it into a flow of token, then parse that flow *)
(* and a second pass where we apply several transformations on the abstract tree expression. *)
(* At all times the abstract tree is of the type Expression, but its expression type changes through the different passes *)
let compile file =
    let lexbuf = Lexing.from_channel file in
    let ast = ref (Parser.program Lexer.token lexbuf) in
    ast := pass1 !ast;
    outputProgram !ast;
    printf "\n\n";
    ast := pass2 !ast;
    
    (* We check that the program is well typed *)
    ast := pass3 !ast;
    
    (* We run the interpreter on the program while it is in DBE form *)
    printf "Interpreting program...\n";
    let v = interpret !ast in
    printf "Result : ";
    outputValue v;
    printf "\n";
    
    (* We convert the program to abstract machine code *)
    ast := pass4 !ast;
    outputProgram !ast;
    
    
    !ast in

(* The compiler body *)
(* We start by reading the file and displaying its content. *)
(* We then compile the file, and display the raw expression obtained. *)
(* Finally, we interpret the program and output its result *)
printf "Input program :\n";
print_file file;
printf "\n\n";
let p = compile file in
match p with
| Code c ->
    printf "Running program on abstract machine...\n";
    let state = AbstractMachine.createInitialState c in
    let res = AbstractMachine.run state in
    printf "Result : ";
    outputAbstractMachineValue res;
    printf "\n"
| _ -> ();