#!/bin/bash

servidorldap="ldaps://ldap1.hpc.cica.es:636"
adminldap="cn=Manager,dc=cica,dc=es"
passldap="-"
ramaldap="ou=supercomputacion,ou=externos,ou=users,ou=cuentas,dc=cica,dc=es"

declare -A Usuariosbloqueados

informar() {
        local nombre=$1
        local pass=$2
        local email=`ldapsearch -H $servidorldap -x -D "$adminldap" -w "$passldap" -b "$ramaldap" -s sub "uid=$nombre" mail |grep ^mail |cut -d " " -f 2`

        echo -e "Estimado usuario: \n\nNos ponemos en contacto con usted para informale que su cuenta $nombre ha sido desbloqueada de los servicios de Supercomputación de CICA. \n\nEstos son los nuevos datos de acceso: \nUsuario: $nombre \nContraseña: $pass" | mail -a "Content-Type: text/plain; charset=UTF-8" -s "Cuenta en los servicios de Supercomputación de CICA" $email
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
	informar $nombre $pass

}

eliminarcuenta() {
	local nombre=$1
	`2>/dev/null 1>/dev/null ldapdelete -H $servidorldap -x -D "$adminldap" -w "$passldap" "uid=$nombre,ou=supercomputacion,ou=externos,ou=users,ou=cuentas,dc=cica,dc=es"`

	echo "La cuenta del usuario $nombre ha sido eliminada."
}	
Acciones() {
	for nombre in "${!Usuariosbloqueados[@]}"; do
		echo "Acciones a realizar con la cuenta de $nombre"
		echo $'Pulse 0 para salir. \nPulse 1 para eliminar la cuenta. \nPulse 2 para desbloquear la cuenta.\n'
		read -n1 -p "Introduzca un opción ha realizar con el usuario: \n" ACCION
		case $ACCION in
			0)
				clear
				echo $'Adios.\n'
				exit;;
			1)
				read -n1 -p "¿Está seguro que desea borrar este usuario?: [s/n]\n" ACCION2
				case $ACCION2 in
					s)
						clear
						eliminarcuenta $nombre
						;;
					n)
						clear
						echo "Usted ha decidido no eliminar la cuenta $nombre"
						;;
				esac
				;;
			2)
				read -n1 -p "¿Está seguro que desea desbloquear este usuario?: [s/n]\n" ACCION3
				case $ACCION3 in
					s)
						clear
						desbloquearcuenta $nombre
						;;
					n)
						clear
						echo "Usted ha decido no desbloquear esta cuenta, $nombre seguirá bloqueada."
						;;
				esac
				;;
			*)
				clear
				echo "ERROR: No existe esa opción" 
				Acciones $nombre
				;;
		esac
	done
}

obtenerdatos=`ldapsearch -H $servidorldap  -x -D "$adminldap" -w "$passldap" -b "$ramaldap" "loginShell" |egrep "^dn:|^loginShell" | tr -d " " | cut -d "," -f 1 | sed s/dn:uid=/"usuario:"/g | tr -d "\n" | sed s/usuario:/"\n"/g | sed s/loginShell:/":"/g`
for i in $obtenerdatos; do
        nombre=`echo $i | cut -d ":" -f 1`
        shell=`echo $i | cut -d ":" -f 2`
		if [[ $shell == "/bin/false" ]]; then
				Usuariosbloqueados[$nombre]=1
		fi
done
Acciones
