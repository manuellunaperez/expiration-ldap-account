#!/bin/bash

servidorldap="ldaps://ldap1.hpc.cica.es:636"
adminldap="cn=Manager,dc=cica,dc=es"
passldap="-"
ramaldap="ou=supercomputacion,ou=externos,ou=users,ou=cuentas,dc=cica,dc=es"

ldapsearch -H $servidorldap -x -D "$adminldap" -w "$passldap" -b "uid=yenny,$ramaldap" "modifyTimestamp" |egrep ^modifyTimestamp
