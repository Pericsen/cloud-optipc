# cloud-optipc

Cloud Computing Grupo 3
Repositorio correspondiente al Grupo 3
Integrantes:
- Tomás Odriozola 62853
- Germán Lorenzani 60250
- Nicolás Peric 59566

### Pasos para correr codigo:
1- En orden de correr los comandos de terraform es necesario tener previamente instalado el CLI de AWS y a su vez configurarlo con las credenciales de la cuenta de AWS a utilizar en el archivo ~/.aws/credentials.
2- Ingresar al archivo terraform.tfvars y modificar los valores de las variables 'domain', 'bucket_name' y 'csv_bucket_name' con valores únicos.
3- (OPCIONAL) En caso de querer comprobar el funcionamiento de SNS y el envío de notificaciones ante una subida a dynamo, agregar también en el archivo terraform.tfvars el mail en el que se desea recibir la notificación.
4- Ejecutar la inicialización de terraform mediante los comandos:
    a. terraform init
    b. terraform plan
    c. terraform apply
4 bis- En caso de haber ingresado su mail en la variable 'suscribers' en terraform.tfvars (paso 3.), recibirá un correo indicando si desea aceptar la recepción de notificaciones. Debe aceptar dicho correo para que esta funcionalidad tenga efecto, una vez que se termine de ejecutar el apply.
5- Listo! Puede ingresar a la web mediante el siguiente enlace (asegúrese de completar {bucket_name} con el valor ingresado para dicha variable en el paso 2.):
    http://{bucket_name}.s3-website-us-east-1.amazonaws.com. O pueden buscar el dominio en el archivo config.json generado al realizar el apply, en el directorio cloud-optipc\front\config.json, en la variable "website_endpoint"



En caso de querer comprobar la funcionalidad de subir otro registro a Dynamo desde el Front, debe iniciar sesión con uno de los usuarios 'Administradores' precargados. Su información de inicio de sesión puede encontrarse en el archivo 'cognito.tf'. El archivo csv './data/registro_para_subir.csv' sirve como ejemplo.

Una vez terminado el apply, verificar que la tabla de dynamodb este poblada ejecutando este codigo en la terminal --> "aws dynamodb scan --table-name componentes", apretar "q" para salir. En caso de que no estén cargados los datos, ejecutar este codigo en la terminal: "python ./data/csv_to_dynamo.py", luego volver a correr el scan.

### Funcionamiento de la página
Una vez en la página, podes ingresar un presupuesto y seleccionar una preferencia de uso de la pc (Gaming, Trabajo o Balanceado), luego ejecutar apretando el boton "Submit".
Tener en cuenta, que una vez presionado el boton "Submit", puede tardar unos segundos en ejecutar.

Una vez ejecutado, se desplegará una lista de componentes, con la opción de modificar algún componente, que al accionar, desplegará una lista nueva de alternativas para ese componente ordenado por precio.

Arriba a la derecha está la opción de hacer login, que al accionar te redigirá a una página propio de cognito.
Existen 2 opciones que recomendamos probar:
- Crear una cuenta propia de OptiPC
- Iniciar sesión como administrador

Una vez hecho el login, los administradores tienen la posibilidad de cargar datos a la base de datos. Para iniciar sesión como administrador, ingresar los siguientes datos:
- Nombre de usuario: admin1@example.com
- Contraseña: Admin@1234 
La página les pedirá que cambien la contraseña, pueden ingresar la misma que está definida anteriormente.

Para probar la funcionalidad de carga de datos, en la esquina superior derecha, hay un símbolo de una nube con una flecha hacia arriba que indica la funcionalidad de carga de datos. Una vez accionada, tienen la opción de "Browse.." con este botón podrás subir el csv correspondiente.
En el directorio /data, buscar el archivo "registro_para_subir.csv", este se puede usar como ejemplo para probar la funcionalidad de carga de datos. Luego, apretar "Subir CSV".
Luego, una vez subida el csv, para comprobar la subida de los datos se puede realizar un query desde la terminal, con el siguiente comando: 

aws dynamodb query \
    --table-name componentes \
    --index-name precio-index \
    --key-condition-expression "partType = :partition_value AND precio_ficticio = :precio_value" \
    --expression-attribute-values '{
        ":partition_value": {"S": "gpu"},
        ":precio_value": {"S": "350.0"}
    }'