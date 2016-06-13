Objetivo: Poner fecha de caducidad en las cuentas creadas de supercomputación.

- La fecha de caducidad estipulada será de 1 año.
- Se informará en un periodo de un mes hasta que la cuenta expire.
- Se informará al usuario y al cica.
- Finalmente se realizarán 2 scripts

estadoldap:
 - Comprueba la fecha de creación de las cuentas de ldap.
 - Busca el estado de cada cuenta, si no tiene estado, se introduce.
 - El estado tendrá el siguiente formato y se actualiza diariamente:
	- Activo,fechacaducidad:$fechacaducidad,vida:$diasrestantes
	- Expirado,actualizado:$diaactual,expiracion:$fechaexpiracion,vida:$diasrestantes
	- Inactivo,actualizado:$diaactual,expiracion:$fechaexpiracion,vida:$diasrestantes
	- Bloqueado
 - Para los usuarios que pasen de activo a expirado, dispondrán de un nuevo periodo de caducidad de 14 dias:
	- Se informa al usuario por mail diciéndole que debe ponerse en contacto con nosotros para renovar su cuenta.
	- Cuando queden 7 dias se le vuelve a informar.
	- Si pasa el tiempo transcurrido se bloquea al usuario automáticamente.

Accionusuarios:

 - Busca los usuarios que están expirados, inactivos o bloqueados.
 - Una vez obtenido los usuarios se preguntará qué accion realizar, siendo las opciones:
	- Renovar: para los usuarios expirados, inactivos y bloqueados.
		- Se le renueva por un periodo de 1 año.
		- Se informa al usuario por correo.
	- Eliminar: para los bloqueados.
