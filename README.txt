Cloud Computing Grupo 3
Repositorio correspondiente al Grupo 3
Pasos para correr codigo:
En orden de correr los comandos de terraform es necesario tener previamente instalado el CLI de AWS y a su vez configurarlo con las credenciales de la cuenta de AWS a utilizar en el archivo ~/.aws/credentials. Tambien es necesario en variables.tf y main.tf usar el buscador para encontrar la palabra "peric" y donde aparezca reemplazarla por el usuario correcto.

Considerando lo explicado anteriormente, para ejecutar el comando de terraform que crea la infraestructura se debe ejecutar el siguiente comando:

terraform init

terraform apply