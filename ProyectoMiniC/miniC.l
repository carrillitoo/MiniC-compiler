%{
#include "miniC.tab.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int comprueba_rango;
int comprueba_length;
#include "listaCodigo.h"
void error();
%}

digito    [0-9]
caracter  [a-zA-Z]
%x COMENT
%option yylineno
%%
                                    
"//"(.*)[\n\r]            ;                  
[ \t\n\r]+                  ;  /*Ignorar espacios, tabulaciones y saltos de línea*/


"/*" 								BEGIN COMENT;
<COMENT>[^*]* 						;
<COMENT>[*]+[/]						BEGIN 0;
<COMENT>[*]+[^/*]*					;

var			            return VAR;
const                   return CONST;
int                     return INT;
if                      return IF;
else                    return ELSE;
for                     return FOR;
do                      return DO;
while                   return WHILE;
print                   return PRINT;
read                    return READ;
"?"			            return QUESTION;
":"			            return DPTOS;
\"([^"\n\\]|\\[ntr"])*\"  { yylval.cadena = strdup(yytext);  return STRING;}
{digito}+                 {if(atoll(yytext) < 2147483648)
	{
		yylval.cadena=strdup(yytext);
		return NUM;
	}
	else
	{
		printf("ERROR LEXICO: Entero fuera de rango permitido: %s\n",yytext);
		yylval.cadena=strdup(yytext);
		return NUM;
	}
 }
({caracter}|_)({caracter}|{digito}|_)*  { if(yyleng <= 32)
	{
		yylval.cadena=strdup(yytext);
		return ID;
	}
	else
	{
		printf("ERROR LEXICO: El identificador excede los %d caracteres %s\n", 32,yytext);
		yylval.cadena=strdup(yytext);
		return ID;
	}
 }

"+"                       return MAS;
"-"                       return MENOS;
"*"                       return POR;
"/"                       return DIV;
"="                       return ASIG;
"<"                       return LT;
">"                       return GT;
"=="					  return EQ;
"!="                      return DIFF;
"<="                      return LTE;
"=<"                      return LTE;
">="                      return GTE;
"=>"                      return GTE;
";"                       return FIN;
","                       return COMMA;
"("                       return PARI;
")"                       return PARD;
"{"                       return LKEY;
"}"                       return RKEY;
([^A-Za-z0-9_\+\-\/\$\*{}()<>!=;,"\[\?\:\n])*   error();

%%

void error() {
    printf("Error en el carácter: %s\n", yytext);
}
