#!/bin/bash

servidorldap="ldaps://ldap1.hpc.cica.es:636"
adminldap="cn=Manager,dc=cica,dc=es"
passldap="-"
ramaldap="ou=supercomputacion,ou=externos,ou=users,ou=cuentas,dc=cica,dc=es"

declare -A Usuariosbloqueados

desbloquearcuenta() {
	local nombre=$1
	local pass=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1` #Generamos una contraseña aleatoria 
	local nuevapass=`slappasswd -h '{MD5}' -s "$pass"` #Ciframos la contraseña 
	`ldapadd -H $servidorldap -x -D "$adminldap" -w "$passldap" << EOF                                                                                  
dn: uid=$nombre,$ramaldap
changeType: modify
replace: userPassword
userPassword: $nuevapass
EOF`

	`ldapadd -H $servidorldap -x -D "$adminldap" -w "$passldap" << EOF                                                                                  
dn: uid=$nombre,$ramaldap
changeType: modify
replace: loginShell
loginShell: /bin/bash
EOF`

	`ldapadd -H $servidorldap -x -D "$adminldap" -w "$passldap" << EOF                                                                                  
dn: uid=$nombre,$ramaldap
changeType: modify
delete: pwdAccountLockedTime
EOF`

	echo "La cuenta del usuario $nombre ha sido renovada."
	echo "Contraseña: $pass"
}

eliminarcuenta() {
	local nombre=$1
	`ldapdelete -H $servidorldap -x -D "$adminldap" -w "$passldap" "uid=$nombre,ou=supercomputacion,ou=externos,ou=users,ou=cuentas,dc=cica,dc=es"`

	echo "La cuenta del usuario $nombre ha sido bloqueada."
}	
Acciones() {
	for nombre in "${!Usuariosbloqueados[@]}"; do
		echo "Acciones a realizar con la cuenta de $nombre"
		echo $'Pulse 0 para salir. \nPulse 1 para eliminar la cuenta. \nPulse 2 para desbloquear la cuenta.'
		read -n1 -p "Introduzca un opción ha realizar con el usuario: " ACCION
		case $ACCION in
			0)
				clear
				echo $'Adios.\n'
				exit;;
			1)
				clear
				echo "La cuenta del usuario $nombre ha sido eliminada."
				eliminarcuenta $nombre
				;;
			2)
				clear
				desbloquearcuenta $nombre
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
