#!/bin/bash

servidorldap="ldaps://ldap1.hpc.cica.es:636"
adminldap="cn=Manager,dc=cica,dc=es"
passldap="-"
ramaldap="ou=supercomputacion,ou=externos,ou=users,ou=cuentas,dc=cica,dc=es"

diaactual=`date +%s`
margenmin=`date +%s --date='-11 month'` #Se avisará cuando quede un mes hasta la fecha de expiracion 
margenmax=`date +%s --date='-12 month'` #El tiempo de expiracion será de 1 año
declare -A Usuariosbloqueados
declare -A Menosde1mes
declare -A Usuariosexpirados

informardesbloqueo() {
        local nombre=$1
        local pass=$2
        local email=`ldapsearch -H $servidorldap -x -D "$adminldap" -w "$passldap" -b "$ramaldap" -s sub "uid=$nombre" mail |grep ^mail |cut -d " " -f 2`

        echo -e "Estimado usuario: \n\nNos ponemos en contacto con usted para informarle que su cuenta $nombre ha sido desbloqueada de los servicios de Supercomputación de CICA. \n\nEstos son los nuevos datos de acceso: \nUsuario: $nombre \nContraseña: $pass" | mail -a "Content-Type: text/plain; charset=UTF-8" -s "Cuenta en los servicios de Supercomputación de CICA" -aFrom:Supercomputacion\ CICA\<eciencia@cica.es\> $email
}

informarrenovacion() {
        local nombre=$1
        local pass=$2
        local email=`ldapsearch -H $servidorldap -x -D "$adminldap" -w "$passldap" -b "$ramaldap" -s sub "uid=$nombre" mail |grep ^mail |cut -d " " -f 2`

        echo -e "Estimado usuario: \n\nNos ponemos en contacto con usted para informarle que su cuenta $nombre ha sido renovada de los servicios de Supercomputación de CICA. \n\nEstos son los nuevos datos de acceso: \nUsuario: $nombre \nContraseña: $pass" | mail -a "Content-Type: text/plain; charset=UTF-8" -s "Cuenta en los servicios de Supercomputación de CICA" -aFrom:Supercomputacion\ CICA\<eciencia@cica.es\> $email
}

informarbloqueo() {
        local nombre=$1
        local email=`ldapsearch -H $servidorldap -x -D "$adminldap" -w "$passldap" -b "$ramaldap" -s sub "uid=$nombre" mail |grep ^mail |cut -d " " -f 2`

        echo -e "Estimado usuario: \n\nNos ponemos en contacto con usted para informarle que su cuenta $nombre ha sido bloqueada de los servicios de Supercomputación de CICA. \nPuede ponerse en contacto con los servicios de supercomputación a través de la dirección de correo eciencia@cica.es." | mail -a "Content-Type: text/plain; charset=UTF-8" -s "Cuenta en los servicios de Supercomputación de CICA" -aFrom:Supercomputacion\ CICA\<eciencia@cica.es\> $email
}

desbloquearcuenta() {
	local nombre=$1
	local pass=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 6 | head -n 1` #Generamos una contraseña aleatoria 
	`2>/dev/null 1>/dev/null ldappasswd  -H $servidorldap -x -D "$adminldap" -w $passldap -s "$pass" "uid=$nombre,$ramaldap"`

	`2>/dev/null 1>/dev/null ldapadd -H $servidorldap -x -D "$adminldap" -w "$passldap" << EOF                                                                                  
dn: uid=$nombre,$ramaldap
changeType: modify
replace: loginShell
loginShell: /bin/bash
EOF`

	`2>/dev/null 1>/dev/null ldapadd -H $servidorldap -x -D "$adminldap" -w "$passldap" << EOF                                                                                  
dn: uid=$nombre,$ramaldap
changeType: modify
delete: pwdAccountLockedTime
EOF`

	echo "La cuenta del usuario $nombre ha sido desbloqueada."
	echo "Usuario: $nombre - Contraseña: $pass" >> usuarios-pass
	informardesbloqueo $nombre $pass

}

eliminarcuenta() {
	local nombre=$1
	`2>/dev/null 1>/dev/null ldapdelete -H $servidorldap -x -D "$adminldap" -w "$passldap" "uid=$nombre,ou=supercomputacion,ou=externos,ou=users,ou=cuentas,dc=cica,dc=es"`

	echo "La cuenta del usuario $nombre ha sido eliminada."
}	

bloquearcuenta() {
	local nombre=$1
		`2>/dev/null 1>/dev/null ldapadd -H $servidorldap -x -D "$adminldap" -w "$passldap" << EOF                                                                                  
dn: uid=$nombre,$ramaldap
changeType: modify
add: pwdAccountLockedTime
pwdAccountLockedTime: 000001010000Z
EOF`
		`2>/dev/null 1>/dev/null ldapadd -H $servidorldap -x -D "$adminldap" -w "$passldap" << EOF                                                                                  
dn: uid=$nombre,$ramaldap
changeType: modify
replace: loginShell
loginShell: /bin/false
EOF`
	echo "La cuenta del usuario $nombre ha sido bloqueada."
	informarbloqueo $nombre 
}	

renovarcuenta() {
	local nombre=$1
	local pass=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 6 | head -n 1` #Generamos una contraseña aleatoria 
	`2>/dev/null 1>/dev/null ldappasswd  -H $servidorldap -x -D "$adminldap" -w $passldap -s "$pass" "uid=$nombre,$ramaldap"`

	echo "La cuenta del usuario $nombre ha sido renovada."
	echo "Usuario: $nombre - Contraseña: $pass"
	informarrenovacion $nombre $pass

}

Accionesbloqueados() {
	for nombre in "${!Usuariosbloqueados[@]}"; do
		echo "Usuario bloqueado: Acciones a realizar con la cuenta de $nombre"
		echo $'Pulse 0 para salir. \nPulse 1 para eliminar la cuenta. \nPulse 2 para desbloquear la cuenta.\nPulse 3 para pasar a la siguiente cuenta.\n'
		read -n1 -p "Introduzca un opción ha realizar con el usuario: " ACCION
		case $ACCION in
			0)
				clear
				echo $'Adios.\n'
				exit;;
			1)
				echo $'\n'
				read -n1 -p "¿Está seguro que desea borrar este usuario?: [s/n]" ACCION2
				case $ACCION2 in
					s)
						clear
						eliminarcuenta $nombre
						;;
					n)
						clear
						echo "La cuenta $nombre no será eliminada."
						;;
				esac
				;;
			2)
				echo $'\n'
				read -n1 -p "¿Está seguro que desea desbloquear este usuario?: [s/n]" ACCION3
				case $ACCION3 in
					s)
						clear
						desbloquearcuenta $nombre
						;;
					n)
						clear
						echo "Se ha decido no desbloquear esta cuenta, $nombre seguirá bloqueada."
						;;
				esac
				;;
			3)
				clear
				echo "Ninguna acción a realizar con la cuenta $nombre ."
				;;
			*)
				clear
				echo "ERROR: No existe esa opción" 
				Accionesbloqueados $nombre
				;;
		esac
	done

}

Accionesmenos1mes() {

	for nombre in "${!Menosde1mes[@]}"; do
		echo "La cuenta $nombre caduca en menos de 1 mes"
		echo $'Pulse 0 para salir. \nPulse 1 para renovar la cuenta. \nPulse 2 para pasar a la siguiente cuenta. \n'
		read -n1 -p "Introduzca un opción ha realizar con el usuario: " ACCION4
		case $ACCION4 in
			0)
				clear
				echo $'Adios.\n'
				exit;;
			1)
				echo $'\n'
				read -n1 -p "¿Está seguro que desea renovar a este usuario?: [s/n]" ACCION5
				case $ACCION5 in
					s)
						clear
						renovarcuenta $nombre
						;;
					n)
						clear
						echo "Ha decidido no renovar la cuenta $nombre"
						;;
				esac
				;;
			2)		
				clear
				echo "Ninguna acción a realizar con la cuenta $nombre ."
				;;
			*)
				clear
				echo "ERROR: No existe esa opción" 
				Accionesmenos1mes $nombre
				;;
		esac
	done
}

Accionesexpirados() {

	for nombre in "${!Usuariosexpirados[@]}"; do
		echo "La cuenta $nombre ha expirado, seleccione una opción a realizar con este usuario."
		echo $'Pulse 0 para salir. \nPulse 1 para renovar la cuenta. \nPulse 2 para bloquear la cuenta.\nPulse 3 para pasar a la siguiente cuenta.\n'
		read -n1 -p "Introduzca un opción ha realizar con el usuario: " ACCION6
		case $ACCION6 in
			0)
				clear
				echo $'Adios.\n'
				exit;;
			1)
				echo $'\n'
				read -n1 -p "¿Está seguro que desea renovar a este usuario?: [s/n]" ACCION7
				case $ACCION7 in
					s)
						clear
						renovarcuenta $nombre
						;;
					n)
						clear
						echo "Ha decidido no renovar la cuenta $nombre"
						;;
				esac
				;;
			2)
				echo $'\n'
				read -n1 -p "¿Está seguro que desea bloquear este usuario?: [s/n]" ACCION8
				case $ACCION8 in
					s)
						clear
						bloquearcuenta $nombre
						;;
					n)
						clear
						echo "La cuenta $nombre no ha sido bloqueada"
						;;
				esac
				;;
			3)
				clear
				echo "Ninguna acción a realizar con la cuenta $nombre ."
				;;
			*)
				clear
				echo "ERROR: No existe esa opción" 
				Accionesexpirados $nombre
				;;
		esac
	done
}


obtenerdatos=`ldapsearch -H $servidorldap  -x -D "$adminldap" -w "$passldap" -b "$ramaldap" "loginShell" |egrep "^dn:|^loginShell" | tr -d " " | cut -d "," -f 1 | sed s/dn:uid=/"usuario:"/g | tr -d "\n" | sed s/usuario:/"\n"/g | sed s/loginShell:/":"/g`
for i in $obtenerdatos; do
        usuario=`echo $i | cut -d ":" -f 1`
        shell=`echo $i | cut -d ":" -f 2`
		if [[ $shell == "/bin/false" ]]; then
				Usuariosbloqueados[$usuario]=1
		fi
done

obtenercaducidad=`ldapsearch -H $servidorldap  -x -D "$adminldap" -w "$passldap" -b "$ramaldap" "modifyTimestamp" |egrep "^dn:|^modifyTimestamp:" | tr -d " " | cut -d "=" -f 2 | tr -d "\n" | sed s/Z/"\n"/g`
for i in $obtenercaducidad; do
	nombre=`echo $i | cut -d "," -f 1`
	fecha=`echo $i | cut -d ":" -f 2 | cut -c 1-8`
	fechaaltaUE=`date --date="$fecha" +%s`
	if [[ $nombre != "supercomputacion" ]]; then
		if [[ $fechaaltaUE -le $margenmin ]] && [[ $fechaaltaUE -gt $margenmax ]]; then
			Menosde1mes[$nombre]=1
		fi
		if [[ $fechaaltaUE -lt $margenmax ]]; then
			comprobarshell=`ldapsearch -H $servidorldap -x -D "$adminldap" -w "$passldap" -b "$ramaldap" "uid=$nombre" loginShell | egrep ^loginShell | cut -d " " -f 2 `
			if [[ $comprobarshell == "/bin/bash" ]]; then
				Usuariosexpirados[$nombre]=1
			fi
		fi
	fi
	
done

Comprobarultimaconexion=`ssh sesamo "bash /opt/scripts/usuarios-ultimaConexion.sh" | egrep -v '(Nunca ha entrado|root|Nombre)' | egrep -v "accedido" | tr -s ' ' | cut -d " " -f 1 | tail -n+4`
for usuario in $Comprobarultimaconexion; do #Comprobamos los usuarios que llevan más de 1 año sin entrar a sesamo y que no estén bloqueados.
	comprobarshell=`ldapsearch -H $servidorldap -x -D "$adminldap" -w "$passldap" -b "$ramaldap" "uid=$usuario" loginShell | egrep ^loginShell | cut -d " " -f 2 `
	if [[ $comprobarshell == "/bin/bash" ]]; then
		Usuariosexpirados[$usuario]=1
	fi
done	
		
Accionesbloqueados
Accionesmenos1mes
Accionesexpirados

