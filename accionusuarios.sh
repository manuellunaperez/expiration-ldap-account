#!/bin/bash

servidorldap="ldaps://ldap1.hpc.cica.es:636"
adminldap="cn=Manager,dc=cica,dc=es"
passldap="-"
ramaldap="ou=supercomputacion,ou=externos,ou=users,ou=cuentas,dc=cica,dc=es"
diaactual=`date +%Y/%m/%d`
diaactualUE=`date +%s`
margenmax=`date +%s --date='-12 month'` #El tiempo de expiracion será de 1 año
declare -A Usuariosexpirados
declare -A Usuariosbloqueados

informarrenovacion() {
	local nombre=$1
	local email=`ldapsearch -H $servidorldap -x -D "$adminldap" -w "$passldap" -b "$ramaldap" -s sub "uid=$nombre" mail |grep ^mail |cut -d " " -f 2`

	echo -e "Estimado usuario: \n\nNos ponemos en contacto con usted para informarle que su cuenta $nombre ha sido renovada de los servicios de Supercomputación de CICA. \n" | mail -a "Content-Type: text/plain; charset=UTF-8" -s "Cuenta en los servicios de Supercomputación de CICA" -c "eciencia@cica.es" -aFrom:Supercomputacion\ CICA\<eciencia@cica.es\> $email
}

renovarcuenta () {
	local nombre=$1
	local fechacaducidad=`date +%Y/%m/%d -d "+ 1 year"`
	local fechacaducidadUE=`date +%s -d "+ 1 year"`
	local diferencia=$(((fechacaducidadUE - diaactualUE) / 86400))
	`2>/dev/null 1>/dev/null ldapadd -H $servidorldap -x -D "$adminldap" -w "$passldap" << EOF                                                                                  
dn: uid=$nombre,$ramaldap
changeType: modify
replace: accountStatus
accountStatus: Activo,fechacaducidad:$fechacaducidad,vida:$diferencia
EOF`	
	informarrenovacion $nombre
	echo "La cuenta del usuario $nombre ha sido renovada"
}

eliminarcuenta() {
	local nombre=$1
	`2>/dev/null 1>/dev/null ldapdelete -H $servidorldap -x -D "$adminldap" -w "$passldap" "uid=$nombre,ou=supercomputacion,ou=externos,ou=users,ou=cuentas,dc=cica,dc=es"`

	echo "La cuenta del usuario $nombre ha sido eliminada."
}	

desbloquearcuenta() {
	local nombre=$1
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
				read -n1 -p "¿Está seguro que desea desbloquear este usuario? Será renovado automáticamente: [s/n]" ACCION3
				case $ACCION3 in
					s)
						clear
						desbloquearcuenta $nombre
						renovarcuenta $nombre
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

Accionesexpirados() {

	for nombre in "${!Usuariosexpirados[@]}"; do
		echo "La cuenta $nombre ha expirado, seleccione una opción a realizar con este usuario."
		echo $'Pulse 0 para salir. \nPulse 1 para renovar la cuenta. \nPulse 3 para pasar a la siguiente cuenta.\n'
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


obtenerestado=`ldapsearch -H $servidorldap  -x -D "$adminldap" -w "$passldap" -b "$ramaldap" "accountStatus" |egrep "^dn:|^accountStatus:" | tr -d " " | sed s/"uid="/"=nombre:"/g | cut -d "=" -f 2 | tr -d "\n" | sed s/"nombre:"/"\n"/g`
for i in $obtenerestado; do
	nombre=`echo $i | cut -d "," -f 1`
	estadocompleto=`echo $i |cut -d ":" -f 2-4`
	estado=`echo $estadocompleto |cut -d "," -f 1`
	if [[ $nombre != "supercomputacion" ]]; then
		if [[ $estado == "Expirado" ]] || [[ $estado == "Inactivo" ]]; then
			Usuariosexpirados[$nombre]=1
		elif [[ $estado == "Bloqueado" ]]; then
			Usuariosbloqueados[$nombre]=1
		fi	
	fi
done

Accionesexpirados
Accionesbloqueados
