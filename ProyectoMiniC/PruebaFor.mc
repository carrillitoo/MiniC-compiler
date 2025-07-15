PruebaFor() {
var int n, suma, sumando, i;
suma = 0;
print("Introduce el numero de sumandos: \n");
read(n);
for (i = 0; i < n; i = i + 1) {
    print("Introduce un sumando:\n");
    read(sumando);
    suma = sumando + suma;
    
    }
    print( "La suma total es: ", suma ,"\n" );
}