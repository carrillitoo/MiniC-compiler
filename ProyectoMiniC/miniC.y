 %{
extern char *yytext;
extern int yylineno;
extern int yylex();
#include <string.h> 
#include <stdio.h>
#include <stdlib.h>
#include "listaSimbolos.h"
#include "listaCodigo.h"
Lista tablaSimbolos;
int tablaRegistros[10];
void liberarRegistro(char * registro);
void siguienteRegistro(char *registro);
void inicializarTablaReg();
char *obtenerEtiqueta();
void yyerror(const char *s);
int contCadenas=1; 
int contadorEtiquetas=1;
int errores = 0;

%}
%code requires {#include "listaCodigo.h"}
%union {
    char *cadena;
    ListaC codigo;
}

%token <cadena> NUM
%token <cadena> ID
%token <cadena> STRING  

%token INT IF ELSE WHILE DO FOR PRINT READ COMMA CONST LKEY RKEY VAR 
%token PARI PARD FIN ASIG
%left GT LT GTE LTE DIFF EQ
%left QUESTION DPTOS
%left MAS MENOS
%left POR DIV 
%left UMENOS

%type <codigo> expression statement print_item print_list read_list statement_list declarations const_list

%%

program: {tablaSimbolos = creaLS();} ID PARI PARD LKEY declarations statement_list RKEY  {
    concatenaLC($6,$7);
    imprimeLS(tablaSimbolos);
    if (errores == 0){imprimeLC($6);}
    liberaLS(tablaSimbolos);
};

declarations: declarations VAR tipo var_list FIN {
        $$ = $1;
    }
    | declarations CONST tipo const_list FIN {
        concatenaLC($1, $4);
        $$ = $1;
    }
    | /* lambda */{
        $$ = creaLC();
    }
    ;
tipo: INT
    ;
var_list : ID {
        if (buscaLS(tablaSimbolos, $1) == finalLS(tablaSimbolos)) {
            Simbolo s;
            s.nombre = $1;
            s.tipo = VARIABLE;
            
            insertaLS(tablaSimbolos, finalLS(tablaSimbolos), s);
        }
        else {printf("Variable %s ya declarada \n", $1);
        errores = errores + 1;
        }
        
    }
    | var_list COMMA ID {if (buscaLS(tablaSimbolos, $3) == finalLS(tablaSimbolos)) {
        Simbolo s;
            s.nombre = $3,
            s.tipo = VARIABLE;
    
        insertaLS(tablaSimbolos, finalLS(tablaSimbolos), s);}
    else{errores = errores + 1;
    printf("Variable %s ya declarada \n",$3);} 
    }
;
const_list : ID ASIG expression {if (buscaLS(tablaSimbolos, $1) == finalLS(tablaSimbolos)){
    Simbolo s;
    
    s.nombre = $1,
    s.tipo = CONSTANTE;

    ListaC lc = $3;

    char nombreVar[20];
    sprintf(nombreVar, "_%s", $1);
    
    Operacion op;
    op.op = "sw";
    op.arg1 = strdup(nombreVar);
    op.arg2 = NULL;
    op.res = recuperaResLC(lc);
    
    insertaLC(lc, finalLC(lc), op); 
    inicializarTablaReg();              /* Puedo vaciar la tabla de registros */
    

    $$ = lc;


        
    insertaLS(tablaSimbolos, finalLS(tablaSimbolos), s);
    }
    else {
    printf("Variable %s ya declarada \n",$1);
    errores = errores + 1;}
    }

    | const_list COMMA ID ASIG expression {
        
        if (buscaLS(tablaSimbolos, $3) == finalLS(tablaSimbolos)) {
        Simbolo s ;
       
        s.nombre = $3,
        s.tipo = CONSTANTE;
        concatenaLC($1, $5);
        ListaC lc = $1;

        char nombreVar[20];
        sprintf(nombreVar, "_%s", $3);
        
        Operacion op;
        op.op = "sw";
        op.arg1 = strdup(nombreVar);
        op.arg2 = NULL;
        op.res = recuperaResLC($5);
        
        insertaLC(lc, finalLC(lc), op); 
        inicializarTablaReg(); 
        $$ = lc;
        insertaLS(tablaSimbolos, finalLS(tablaSimbolos), s);
        }
        
        else {
        printf("Variable %s ya declarada \n",$3);
        errores = errores + 1;}
        }
        ;

statement_list: statement_list statement {
        concatenaLC($1,$2);
        $$ = $1;
    }
    | /* lambda */ {
        $$ = creaLC();
    }
    ;

statement: ID ASIG expression FIN { 
    
            PosicionLista s = buscaLS(tablaSimbolos, $1);             
            if (s == finalLS(tablaSimbolos)) {printf("Variable %s no declarada \n",$1);
            errores = errores + 1;}
            else if (recuperaLS(tablaSimbolos, s).tipo == CONSTANTE) {
            printf("Asignación a constante\n");
            errores = errores + 1;}
            
            ListaC lc = $3;
            char nombreVar[20];
            sprintf(nombreVar, "_%s", $1);
            Operacion op;
            op.op = "sw";
            op.arg1 = strdup(nombreVar);
            op.arg2 = NULL;
            op.res = recuperaResLC(lc);
        
            insertaLC(lc, finalLC(lc), op); 
            
            inicializarTablaReg();              /* Puedo vaciar la tabla de registros */
            

            $$ = lc;
            

            }    
        | IF PARI expression PARD statement {
            ListaC lc = creaLC();
            
            
            concatenaLC(lc, $3);
            
            char *etiquetaFin = obtenerEtiqueta(); // Etiqueta para el final del IF
            
         
            Operacion opJump;
            opJump.op = "beqz";  
            opJump.arg1 = etiquetaFin;
            opJump.arg2 = NULL;          
            opJump.res = recuperaResLC($3);       
            insertaLC(lc, finalLC(lc), opJump);
            liberarRegistro(recuperaResLC($3));
           
            concatenaLC(lc, $5);  

            Operacion op1;
            op1.op = etiquetaFin;
            op1.arg1 = NULL;
            op1.arg2 = NULL; 
            op1.res = ":";
            insertaLC(lc, finalLC(lc), op1); 

            $$ = lc;

        }
    | IF PARI expression PARD statement ELSE statement {
                
            ListaC lc = creaLC();

      
            concatenaLC(lc, $3);

        
            char *etiquetaElse = obtenerEtiqueta();
            char *etiquetaFin = obtenerEtiqueta();

            char *reg_cond = recuperaResLC($3);
            Operacion opJumpElse;
            opJumpElse.op = "beqz";  
            opJumpElse.arg1 = etiquetaElse;
            opJumpElse.arg2 = NULL;
            opJumpElse.res = reg_cond ;
            insertaLC(lc, finalLC(lc), opJumpElse);

            liberarRegistro(reg_cond);

          
            concatenaLC(lc, $5);

      
            Operacion opJumpFin;
            opJumpFin.op = "b";
            opJumpFin.arg1 = NULL;
            opJumpFin.arg2 = NULL;
            opJumpFin.res = etiquetaFin;
            insertaLC(lc, finalLC(lc), opJumpFin);

     
            Operacion opEtiquetaElse;
            opEtiquetaElse.op = etiquetaElse;
            opEtiquetaElse.arg1 = NULL;
            opEtiquetaElse.arg2 = NULL;
            opEtiquetaElse.res = ":";
            insertaLC(lc, finalLC(lc), opEtiquetaElse);

        
            concatenaLC(lc, $7);

           
            Operacion opEtiquetaFin;
            opEtiquetaFin.op = etiquetaFin;
            opEtiquetaFin.arg1 = NULL;
            opEtiquetaFin.arg2 = NULL;
            opEtiquetaFin.res = ":";
            insertaLC(lc, finalLC(lc), opEtiquetaFin);

            $$ = lc;
    }
    | WHILE PARI expression PARD statement {
            ListaC lc = creaLC();

            char *etiquetaInicio = obtenerEtiqueta();
            Operacion op;
            op.op = etiquetaInicio;
            op.arg1 = NULL;
            op.arg2 = NULL; 
            op.res = ":";
            insertaLC(lc, finalLC(lc), op);

            char *etiquetaFin = obtenerEtiqueta();

          
        
            concatenaLC(lc, $3);
        

           
            Operacion opCondicion;
            opCondicion.op = "beqz";
            opCondicion.arg1 = etiquetaFin;  
            opCondicion.arg2 =NULL;      
            opCondicion.res = recuperaResLC($3);
            insertaLC(lc, finalLC(lc), opCondicion);

            liberarRegistro(recuperaResLC($3));

           
        
            concatenaLC(lc, $5);
        

          
            Operacion opSalto;
            opSalto.op = "b";    
            opSalto.arg1 = NULL;
            opSalto.arg2 = NULL;
            opSalto.res = etiquetaInicio;
            insertaLC(lc, finalLC(lc), opSalto);
            
            Operacion op1;
            op1.op = etiquetaFin;
            op1.arg1 = NULL;
            op1.arg2 = NULL; 
            op1.res = ":";
            insertaLC(lc, finalLC(lc), op1);
            $$ = lc;
    }
    | DO statement WHILE PARI expression PARD FIN {
            ListaC lc = creaLC();
            
            char *etiquetaInicio = obtenerEtiqueta();
            Operacion op;
            op.op = etiquetaInicio;
            op.arg1 = NULL;
            op.arg2 = NULL; 
            op.res = ":";
            insertaLC(lc, finalLC(lc), op);
            

        
    
            concatenaLC(lc, $2);
            

          
            
            concatenaLC(lc, $5);
        

         
            Operacion opJump;
            opJump.op = "bnez";
            opJump.arg1 = etiquetaInicio;
            opJump.arg2 = NULL;
            opJump.res = recuperaResLC($5);
            insertaLC(lc, finalLC(lc), opJump);

           
            liberarRegistro(recuperaResLC($5));

        
            $$ = lc;
        }
    
    | FOR PARI ID ASIG expression FIN expression FIN ID ASIG expression PARD statement {
            ListaC lc = creaLC();

            PosicionLista s = buscaLS(tablaSimbolos, $3);             
            if (s == finalLS(tablaSimbolos)) {printf("Variable %s no declarada \n",$3);
            errores = errores + 1;}
            else if (recuperaLS(tablaSimbolos, s).tipo == CONSTANTE){errores = errores + 1;
            printf("Asignación a constante\n");}       
        
            PosicionLista s2 = buscaLS(tablaSimbolos, $9);
            if (s2 == finalLS(tablaSimbolos)) {printf("Variable %s no declarada\n", $9);
            errores = errores + 1;}
            else if (recuperaLS(tablaSimbolos, s2).tipo == CONSTANTE) {errores = errores + 1;
            printf("Asignación a constante\n");}

           
            concatenaLC(lc, $5);
            char nombreVar[20];
            sprintf(nombreVar, "_%s", $3);
            Operacion opInit;
            opInit.op = "sw";
            opInit.arg1 =strdup(nombreVar);
            opInit.arg2 = NULL;
            opInit.res = recuperaResLC($5);
            insertaLC(lc, finalLC(lc), opInit);

            liberarRegistro(recuperaResLC($5));
            
          
            char *etiquetaInicio = obtenerEtiqueta();
            Operacion etInicio;
            etInicio.op = etiquetaInicio;
            etInicio.arg1 = NULL;
            etInicio.arg2 = NULL;
            etInicio.res = ":";
            insertaLC(lc, finalLC(lc), etInicio);

          
            concatenaLC(lc, $7);
        

            
            char *etiquetaFin = obtenerEtiqueta();

         
            Operacion opCond;
            opCond.op = "beqz";
            opCond.arg1 = etiquetaFin;
            opCond.arg2 = NULL;
            opCond.res = recuperaResLC($7);
            insertaLC(lc, finalLC(lc), opCond);

            liberarRegistro(recuperaResLC($7));

           
            concatenaLC(lc, $13);
            
          
            concatenaLC(lc, $11);
            char nombreVar1[20];
            sprintf(nombreVar1, "_%s", $9);
            Operacion opInc;
            opInc.op = "sw";
            opInc.arg1 = strdup(nombreVar1);
            opInc.arg2 = NULL;
            opInc.res = recuperaResLC($11);
            insertaLC(lc, finalLC(lc), opInc);

            liberarRegistro(recuperaResLC($11));

          
            Operacion opSalto;
            opSalto.op = "b";
            opSalto.arg1 = NULL;
            opSalto.arg2 = NULL;
            opSalto.res = etiquetaInicio;
            insertaLC(lc, finalLC(lc), opSalto);

           
            Operacion etFin;
            etFin.op = etiquetaFin;
            etFin.arg1 = NULL;
            etFin.arg2 = NULL;
            etFin.res = ":";
            insertaLC(lc, finalLC(lc), etFin);

            $$ = lc;
    }


    | PRINT PARI print_list PARD FIN {
    
            $$ = $3;
    }   
    | READ PARI read_list PARD FIN {
    
            $$ = $3;
    }
    | LKEY statement_list RKEY {
            $$ = $2;
    }
    ;

print_list: print_item  {
       
            $$ = $1;
        }
        | print_list COMMA print_item {
        
            concatenaLC($1, $3);
            
            $$ = $1;
        
        }
        ;

print_item: expression  {
            // Asignar a $$ el contenido de $1 seguido de instrucciones para imprime
            ListaC lc = $1;
            char *reg_resultado = recuperaResLC(lc);
            
            // Instrucción para mover el resultado a $a0
            Operacion op_move;
            op_move.op = "move";
            op_move.arg1 = reg_resultado;
            op_move.arg2 = NULL;
            op_move.res = "$a0";
            insertaLC(lc, finalLC(lc), op_move);
            
            // Instrucción para configurar print_int (código 1)
            Operacion op_li;
            op_li.op = "li";
            op_li.arg1 = "1";  // Código para print_int
            op_li.arg2 = NULL;
            op_li.res = "$v0";
            insertaLC(lc, finalLC(lc), op_li);
            
            // Llamada al sistema
            Operacion op_syscall;
            op_syscall.op = "syscall";
            op_syscall.arg1 = NULL;
            op_syscall.arg2 = NULL;
            op_syscall.res = NULL;
            insertaLC(lc, finalLC(lc), op_syscall);
            
            liberarRegistro(reg_resultado);
            $$ = lc;
    }
    | STRING { Simbolo s;
            s.nombre = $1,
            s.tipo = CADENA;
            s.valor = contCadenas;
            
            insertaLS(tablaSimbolos, finalLS(tablaSimbolos), s);
            
            ListaC lc = creaLC();

            Operacion op1;
            op1.op = "la"; 
            
            char  etiqueta[32];
            sprintf(etiqueta,"$str%d",contCadenas++);
            op1.arg1 = NULL;
            op1.arg2 = strdup(etiqueta) ;
            char *registro = malloc(5 * sizeof(char));
            siguienteRegistro(registro); 
            op1.res = "$a0";

            insertaLC(lc, finalLC(lc), op1);

            Operacion op3;
            op3.op = "li";
            op3.arg1 = "4"; // código para imprime string
            op3.arg2 = NULL;
            op3.res = "$v0";
            insertaLC(lc, finalLC(lc), op3);
        
            Operacion op4;
            op4.op = "syscall";
            op4.arg1 = NULL;
            op4.arg2 = NULL;
            op4.res = NULL;
            insertaLC(lc, finalLC(lc), op4);

            liberarRegistro(registro);
            
            $$ = lc;
        
            }
    ;

read_list: ID {PosicionLista s = buscaLS(tablaSimbolos, $1);
                
            if (s == finalLS(tablaSimbolos)) {printf("Variable %s no declarada \n",$1);
            errores = errores + 1;}
            else if (recuperaLS(tablaSimbolos, s).tipo == CONSTANTE) {printf("Asignación a constante\n");
            errores = errores + 1;}
            
            ListaC lc = creaLC();
                
              
                Operacion op1;
                op1.op = "li";
                op1.arg1 = "5";
                op1.arg2 = NULL;
                op1.res = "$v0";
                insertaLC(lc, finalLC(lc), op1);
                
              
                Operacion op2;
                op2.op = "syscall";
                op2.arg1 = NULL;
                op2.arg2 = NULL;
                op2.res = NULL;
                insertaLC(lc, finalLC(lc), op2);
                
                char nombreVar[20];
                sprintf(nombreVar, "_%s", $1);

            
                Operacion op3;
                op3.op = "sw";
                op3.arg1 = strdup(nombreVar);    
                op3.arg2 = NULL;
                op3.res = "$v0";  
                insertaLC(lc, finalLC(lc), op3);
                
                $$ = lc;  

            }
    
    | read_list COMMA ID { PosicionLista s = buscaLS(tablaSimbolos, $3);
                
                if(s == finalLS(tablaSimbolos)) {printf("Variable %s no declarada \n",$3);
                errores = errores + 1;}
                else if (recuperaLS(tablaSimbolos, s).tipo == CONSTANTE) {printf("Asignación a constante\n");
                errores = errores + 1;}
                            
                ListaC lc = creaLC();
                
                Operacion op_li;
                op_li.op = "li";
                op_li.arg1 = "5"; 
                op_li.arg2 = NULL;
                op_li.res = "$v0";
                insertaLC(lc, finalLC(lc), op_li);
                
                Operacion op_sys;
                op_sys.op = "syscall";
                op_sys.arg1 = NULL;
                op_sys.arg2 = NULL;
                op_sys.res = NULL;
                insertaLC(lc, finalLC(lc), op_sys);

                char nombreVar[20];
                sprintf(nombreVar, "_%s", $3);
                Operacion op_sw;
                op_sw.op = "sw";
                op_sw.arg1 = strdup(nombreVar);
                op_sw.arg2 = NULL;
                op_sw.res = "$v0";
                insertaLC(lc, finalLC(lc), op_sw);
                
                concatenaLC($1, lc);
        
                $$ = $1;       
                }
    ;

expression: expression MAS expression {
        
            concatenaLC($1, $3);
            
            ListaC lc = $1;
            
            Operacion op;
            op.op = "add";
            op.arg1 = recuperaResLC($1);
            op.arg2 = recuperaResLC($3);
            op.res = op.arg1;

            liberarRegistro(op.arg2);

            guardaResLC(lc, op.res);  
            insertaLC(lc, finalLC(lc), op);    
        
            $$ = lc;

} 
    | expression MENOS expression {
        
            concatenaLC($1, $3);
        
            ListaC lc = $1;
            
            Operacion op;
            op.op = "sub";
            op.arg1 = recuperaResLC($1);
            op.arg2 = recuperaResLC($3);
            op.res = op.arg1;

            liberarRegistro(op.arg2);

            guardaResLC(lc, op.res);  
            insertaLC(lc, finalLC(lc), op);    
        
            $$ = lc;

    } 
    | expression POR expression {
        
            concatenaLC($1, $3);
    
            ListaC lc = $1;
            
            Operacion op;
            op.op = "mul";
            op.arg1 = recuperaResLC($1);
            op.arg2 = recuperaResLC($3);
            op.res = op.arg1;

            liberarRegistro(op.arg2);

            guardaResLC(lc, op.res);  
            insertaLC(lc, finalLC(lc), op);    
            
            $$ = lc;

    }
    | expression DIV expression {
        
        concatenaLC($1, $3);
    
        ListaC lc = $1;
        
        Operacion op;
        op.op = "div";
        op.arg1 = recuperaResLC($1);
        op.arg2 = recuperaResLC($3);
        op.res = op.arg1;

        liberarRegistro(op.arg2);

        guardaResLC(lc, op.res);  
        insertaLC(lc, finalLC(lc), op);    
    
        $$ = lc;

    }
    | PARI expression QUESTION expression DPTOS expression PARD {
        ListaC lc = creaLC();

        char *etiquetaFalse = obtenerEtiqueta();
        char *etiquetaFin = obtenerEtiqueta();

    
        concatenaLC(lc,$2);
    

      
        Operacion opJumpFalse;
        opJumpFalse.op = "beqz";
        opJumpFalse.arg1 = etiquetaFalse;
        opJumpFalse.arg2 = NULL;
        opJumpFalse.res = recuperaResLC($2);
        insertaLC(lc, finalLC(lc), opJumpFalse);

        
        concatenaLC(lc, $4);
        Operacion opMove1;
        opMove1.op = "move";
        opMove1.arg1 = recuperaResLC($4);
        opMove1.arg2 = NULL;
        opMove1.res = recuperaResLC($2);
        insertaLC(lc, finalLC(lc), opMove1);

       
        Operacion opJumpFin;
        opJumpFin.op = "b";
        opJumpFin.arg1 = NULL;
        opJumpFin.arg2 = NULL;
        opJumpFin.res = etiquetaFin ;
        insertaLC(lc, finalLC(lc), opJumpFin);

        Operacion opEtiqueta;
        opEtiqueta.op =  etiquetaFalse;
        opEtiqueta.arg1 = NULL;
        opEtiqueta.arg2 = NULL;
        opEtiqueta.res = ":";
        insertaLC(lc, finalLC(lc), opEtiqueta);
        concatenaLC(lc, $6);

        Operacion opMove2;
        opMove2.op = "move";
        opMove2.arg1 = recuperaResLC($6);
        opMove2.arg2 = NULL;
        opMove2.res = recuperaResLC($2);
        insertaLC(lc, finalLC(lc), opMove2);
        
        Operacion opEtiqueta2;
        opEtiqueta2.op =  etiquetaFin;
        opEtiqueta2.arg1 = NULL;
        opEtiqueta2.arg2 = NULL;
        opEtiqueta2.res = ":";
        insertaLC(lc, finalLC(lc), opEtiqueta2);
       
        guardaResLC(lc, recuperaResLC($2));
        $$ = lc;
        liberarRegistro(recuperaResLC($4));
        liberarRegistro(recuperaResLC($6));

        liberaLC($4);
        liberaLC($6);
    } 
    | expression GT expression {
        concatenaLC($1, $3);
            
            ListaC lc = $1;
            
            Operacion op;
            op.op = "sgt";
            op.arg1 = recuperaResLC($1);
            op.arg2 = recuperaResLC($3);
            op.res = op.arg1;

            liberarRegistro(op.arg2);

            guardaResLC(lc, op.res);  
            insertaLC(lc, finalLC(lc), op);    
        
            $$ = lc;
    }
    | expression GTE expression {
        concatenaLC($1, $3);
            
            ListaC lc = $1;
            
            Operacion op;
            op.op = "sge";
            op.arg1 = recuperaResLC($1);
            op.arg2 = recuperaResLC($3);
            op.res = op.arg1;

            liberarRegistro(op.arg2);

            guardaResLC(lc, op.res);  
            insertaLC(lc, finalLC(lc), op);    
        
            $$ = lc;
    }
    | expression LT expression {
        concatenaLC($1, $3);
            
            ListaC lc = $1;
            
            Operacion op;
            op.op = "slt";
            op.arg1 = recuperaResLC($1);
            op.arg2 = recuperaResLC($3);
            op.res = op.arg1;

            liberarRegistro(op.arg2);

            guardaResLC(lc, op.res);  
            insertaLC(lc, finalLC(lc), op);  
        
            liberarRegistro(op.arg2);
          
        
            $$ = lc;
    }
    | expression LTE expression {
        concatenaLC($1, $3);
            
            ListaC lc = $1;
            
            Operacion op;
            op.op = "sle";
            op.arg1 = recuperaResLC($1);
            op.arg2 = recuperaResLC($3);
            op.res = op.arg1;

            

            guardaResLC(lc, op.res);  
            insertaLC(lc, finalLC(lc), op);    
            liberarRegistro(op.arg2);
        
            $$ = lc;
    }
    | expression DIFF expression {
        concatenaLC($1, $3);
            
            ListaC lc = $1;
            
            Operacion op;
            op.op = "sne"; /*set not equal*/
            op.arg1 = recuperaResLC($1);
            op.arg2 = recuperaResLC($3);
            op.res = op.arg1;

            liberarRegistro(op.arg2);

            guardaResLC(lc, op.res);  
            insertaLC(lc, finalLC(lc), op);    
        
            $$ = lc;
    }
    | expression EQ expression {
        concatenaLC($1, $3);
            
            ListaC lc = $1;
            
            Operacion op;
            op.op = "seq"; /*set equal*/
            op.arg1 = recuperaResLC($1);
            op.arg2 = recuperaResLC($3);
            op.res = op.arg1;

            liberarRegistro(op.arg2);

            guardaResLC(lc, op.res);  
            insertaLC(lc, finalLC(lc), op);    
        
            $$ = lc;
    }
    | PARI expression PARD {
        $$ = $2;

    } 
    | MENOS expression %prec UMENOS {
        ListaC lc = $2;

        Operacion op;
        op.op = "neg";
        op.res = recuperaResLC(lc);
        op.arg1 = recuperaResLC(lc);
        op.arg2 = NULL;
        insertaLC(lc, finalLC(lc), op);
        

        $$ = lc;

    }
    | ID {
        if (buscaLS(tablaSimbolos, $1) == finalLS(tablaSimbolos)) {printf("Variable %s no declarada \n",$1);
        errores = errores + 1;}
        ListaC lc = creaLC();
        char *registro = malloc(5 * sizeof(char));
        siguienteRegistro(registro);
        
        char nombreVar[20];
        sprintf(nombreVar, "_%s", $1);
        
        Operacion op;
        op.op = "lw";
        op.arg1 = strdup(nombreVar);
        op.arg2 = NULL;
        op.res = registro;

        insertaLC(lc, finalLC(lc), op); 
        guardaResLC(lc, registro);      
        
        $$ = lc; 

        
        } 
    
    | NUM {
        ListaC lc = creaLC();
        char *registro = malloc(5 * sizeof(char));
        siguienteRegistro(registro);

        Operacion op;
        op.op = "li";
        op.arg1 = $1;
        op.arg2 = NULL;
        op.res = registro;

        insertaLC(lc, finalLC(lc), op); 
        guardaResLC(lc, registro);      
        
        $$ = lc; 
    }
    ;

%%

void yyerror(const char *s){
    printf("Error sintático en el token %s y linea %d\n",yytext, yylineno);
}

void liberarRegistro(char * registro) {
    int indice = atoi(registro + 2); 
    tablaRegistros[indice] = 0;
}

void inicializarTablaReg(){
    for(int i = 0; i < 10; i++ ){
        tablaRegistros[i] = 0;              /* Se inicializa a cero porque está vacia obviamente */
    }
}

void siguienteRegistro(char *registro) {
    for (int i = 0; i < 10; i++) {
        if (tablaRegistros[i] == 0) {       /* Busca un registro libre */
            tablaRegistros[i] = 1;          /* Marca el registro como ocupado */
            sprintf(registro, "$t%d", i);    /* Asigna el nombre del registro a la variable 'registro' */
            return;                         /* Salir después de asignar el primer registro libre */
        }
    }
    // Si llegamos aquí es porque no hay registros libres
    printf("No hay registros libres.\n");
}
char *obtenerEtiqueta() {
    char aux[32];
    sprintf(aux,"$label%d",contadorEtiquetas++);
    return strdup(aux);
}
