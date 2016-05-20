#!/bin/bash

servidorldap="ldaps://ldap1.hpc.cica.es:636"
adminldap="cn=Manager,dc=cica,dc=es"
passldap="-"
ramaldap="ou=supercomputacion,ou=externos,ou=users,ou=cuentas,dc=cica,dc=es"
diaactual=`date +%s`
margenmin=`date +%s --date='-11 month'` #Se avisará cuando quede un mes hasta la fecha de expiración 
margenmax=`date +%s --date='-12 month'` #El tiempo de expiración será de 1 año
declare -A Usuariosexpirados


renovarcuenta() {
	local nombre=$1
	local pass=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1` #Generamos una contraseña aleatoria 
	local nuevapass=`slappasswd -h '{MD5}' -s "$pass"` #Ciframos la contraseña 
	`ldapadd -H $servidorldap -x -D "$adminldap" -w "$passldap" << EOF                                                                                  
dn: uid=$nombre,$ramaldap
changeType: modify
replace: userPassword
userPassword: $nuevapass
EOF`
	echo "La cuenta del usuario $nombre ha sido renovada."
	echo "Contraseña: $pass"
}
bloquearcuenta() {
	local nombre=$1
	`ldapadd -H $servidorldap -x -D "$adminldap" -w "$passldap" << EOF                                                                                  
dn: uid=$nombre,$ramaldap
changeType: modify
add: pwdAccountLockedTime
pwdAccountLockedTime: 000001010000Z
EOF`
	`ldapadd -H $servidorldap -x -D "$adminldap" -w "$passldap" << EOF                                                                                  
dn: uid=$nombre,$ramaldap
changeType: modify
replace: loginShell
loginShell: /bin/false
EOF`
	echo "La cuenta del usuario $nombre ha sido bloqueada."
}	
Calculardias() {
	local nombre=$1
	local fecha=$2
	local fechacaducidad=`date +%Y/%m/%d -d "$fecha + 1 year"`
	local fechacaducidadUE=`date +%s -d "$fecha + 1 year"`
	local diferencia=$(( ( fechacaducidadUE - diaactual) / 86400 ))
	echo "La fecha de expiración de la cuenta del usuario $nombre se aproxima: $fechacaducidad"
	echo "Quedan $diferencia dias para que expire la cuenta"
}
Acciones() {
	for nombre in "${!Usuariosexpirados[@]}"; do
		echo "La cuenta del usuario $nombre ha caducado"
		echo $'Pulse 0 para salir. \nPulse 1 para bloquear la cuenta. \nPulse 2 para renovar la cuenta.'
		read -n1 -p "Introduzca un opción ha realizar con el usuario: " ACCION
		case $ACCION in
			0)
				clear
				echo $'Adios.\n'
				exit;;
			1)
				clear
				echo "La cuenta del usuario $nombre ha sido bloqueada."
				bloquearcuenta $nombre
				;;
			2)
				clear
				renovarcuenta $nombre
				;;
			*)
				clear
				echo "ERROR: No existe esa opción" 
				Acciones $nombre
				;;
		esac
	done
}


Comprobarultimaconexion=`ssh sesamo "bash /opt/scripts/usuarios-ultimaConexion.sh" | egrep -v '(Nunca ha entrado|root|Nombre)' | tr -s ' ' | cut -d " " -f 1 | tail -n+4`
obtenerdatos=`ldapsearch -H $servidorldap  -x -D "$adminldap" -w "$passldap" -b "$ramaldap" "modifyTimestamp" |egrep "^dn:|^modifyTimestamp:" | tr -d " " | cut -d "=" -f 2 | tr -d "\n" | sed s/Z/"\n"/g`
for i in $obtenerdatos; do
	nombre=`echo $i | cut -d "," -f 1`
	fecha=`echo $i | cut -d ":" -f 2 | cut -c 1-8`
	fechaaltaUE=`date --date="$fecha" +%s`
	if [[ $nombre != "supercomputacion" ]]; then
		if [[ $fechaaltaUE -le $margenmin ]] && [[ $fechaaltaUE -gt $margenmax ]]; then
			Calculardias $nombre $fecha
		fi	
		if [[ $fechaaltaUE -lt $margenmax ]]; then
			Usuariosexpirados[$nombre]=1
		fi
	fi
done
for usuario in $Comprobarultimaconexion; do #Comprobamos los usuarios que llevan más de 1 año sin entrar a sesamo y que no estén bloqueados.
	comprobarshell=`ldapsearch -H $servidorldap -x -D "$adminldap" -w "$passldap" -b "$ramaldap" "uid=$usuario" loginShell | egrep ^loginShell | cut -d " " -f 2 `
	if [[ $comprobarshell == "/bin/bash" ]]; then
		Usuariosexpirados[$usuario]=1
	fi
done
Acciones


