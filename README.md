# cloud-optipc

Cloud Computing Grupo 3
Repositorio correspondiente al Grupo 3

Pasos para correr codigo:
1- En orden de correr los comandos de terraform es necesario tener previamente instalado el CLI de AWS y a su vez configurarlo con las credenciales de la cuenta de AWS a utilizar en el archivo ~/.aws/credentials.
2- Ingresar al archivo terraform.tfvars y modificar los valores de las variables 'domain', 'bucket_name' y 'csv_bucket_name' con valores únicos.
3- (OPCIONAL) En caso de querer comprobar el funcionamiento de SNS y el envío de notificaciones ante una subida a dynamo, agregar también en el archivo terraform.tfvars el mail en el que se desea recibir la notificación.
4- Ejecutar la inicialización de terraform mediante los comandos:
    a. terraform init
    b. terraform plan
    c. terraform apply
4 bis- En caso de haber ingresado su mail en la variable 'suscribers' en terraform.tfvars (paso 3.), recibirá un correo indicando si desea aceptar la recepción de notificaciones. Debe aceptar dicho correo para que esta funcionalidad tenga efecto.
5- Listo! Puede ingresar a la web mediante el siguiente enlace (asegúrese de completar {bucket_name} con el valor ingresado para dicha variable en el paso 2.):
    http://{bucket_name}.s3-website-us-east-1.amazonaws.com


En caso de querer comprobar la funcionalidad de subir otro registro a Dynamo desde el Front, debe iniciar sesión con uno de los usuarios 'Administradores' precargados. Su información de inicio de sesión puede encontrarse en el archivo 'cognito.tf'. El archivo csv './data/registro_para_subir.csv' sirve como ejemplo.