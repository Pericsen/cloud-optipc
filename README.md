# cloud-optipc

## Cloud Computing Grupo 3
### Integrantes:
- Tomás Odriozola 62853
- Germán Lorenzani 60250
- Nicolás Peric 59566

### Pasos para correr codigo:
1. En primer lugar, para correr los comandos de terraform es necesario tener previamente instalado el CLI de AWS y a su vez configurarlo con las credenciales de la cuenta de AWS a utilizar en el archivo ~/.aws/credentials.
2. Ingresar al archivo terraform.tfvars y modificar los valores de las variables 'domain', 'bucket_name' y 'csv_bucket_name' con valores únicos.
3. (OPCIONAL) En caso de querer comprobar el funcionamiento de SNS y el envío de notificaciones ante una subida a dynamo, agregar también en el archivo terraform.tfvars el mail en el que se desea recibir la notificación.
4. Ejecutar la inicialización de terraform mediante los comandos:
    a. terraform init
    b. terraform plan
    c. terraform apply
4 bis. En caso de haber ingresado su mail en la variable 'suscribers' en terraform.tfvars (paso 3.), recibirá un correo indicando si desea aceptar la recepción de notificaciones. Una vez que se termine de ejecutar el apply, debe aceptar dicho correo para que esta funcionalidad tenga efecto.
5. Listo! Puede ingresar a la web mediante el siguiente enlace (asegúrese de completar {bucket_name} con el valor ingresado para dicha variable en el paso 2.): 'http://{bucket_name}.s3-website-us-east-1.amazonaws.com'. O también puede obtener el dominio de la web en la variable 'website_endpoint' del JSON './front/config.json' una vez realizado el apply.
6. Una vez terminado el apply, verificar que la tabla de dynamodb se encuentre poblada ejecutando el siguiente código en la terminal: aws dynamodb scan --table-name componentes.
   Apretar "q" para salir. En caso de que no estén cargados los datos, ejecutar este codigo en la terminal: python ./data/csv_to_dynamo.py. Luego volver a correr el scan.

### Funcionamiento de la página
Una vez levantada toda la arquitectura, al ingresar a la página se observará una sección principal con la funcionalidad core de la web y otra sección en la esquina superior derecha permitiendo el inicio de sesión. 

En la sección principal, se debe ingresar un presupuesto y seleccionar una preferencia de uso de la pc (Gaming, Trabajo o Balanceado) para obtener los resultados de los componentes seleccionados por el modelo de optimización en función del presupuesto y las preferencias indicadas. Luego ejecutar apretando el boton "Submit". Tener en cuenta que una vez presionado el boton "Submit", el modelo puede tardar unos segundos en ejecutar y mostrar los resultados en pantalla.

Una vez ejecutado, se desplegará una lista de componentes seleccionados por el modelo como los que más encajan con las condiciones estipuladas. Sin embargo, en cada uno de ellos aparecerá una opción de modificar el componente por otro de la lista. Al accionar este botón, se desplegará una lista nueva de alternativas para ese componente ordenada por precio. Al seleccionar alguna de estas, se reemplaza la opción original seleccionada por el modelo.

Con respecto al inicio de sesión, en la esquina superior derecha se encuentra un botón con la indicación 'Login'. En caso de apretarlo, la página le redirigirá a la UI de inicio de sesión propia de Cognito. En ella se recomienda la prueba de dos alternativas:
- Crear una cuenta propia de OptiPC con mail personal
- Iniciar sesión como usuario administrador

Al inciar sesión como usuario administrador, además del botón de visualización del perfil con su nombre de usuario y mail, también visualizará un ícono de una nube. Este ícono representa la funcionalidad de carga de datos directa hacia la base de datos alojada en DynamoDB. Esta función se encuentra únicamente disponible al iniciar sesión como usuario administrador. Para hacer esto, debe ingresar las credenciales asociadas a uno de los usuarios Admin creados en el apply de la arquitectura. Las credenciales de uno de ellos son:
- Nombre de usuario: admin1@example.com
- Contraseña: Admin@1234 

Al iniciar sesión como administrador, la página le solicitará un cambio de contraseña. En ella, deberá ingresar una contraseña propia que se asociará automáticamente al usuario admin para luego iniciar sesión con dicha contraseña.

Para probar la funcionalidad de carga de datos, una vez accionado el botón de la nube asociado a esta funcionalidad, se abre una ventana emergente con la opción de seleccionar del navegador un archivo de extensión .csv para subir a la base de datos. Para realizar la prueba, en el directorio './data', se reservó un archivo bajo el nombre "registro_para_subir.csv" que puede ser usado como ejemplo para probar esta mecánica. Luego, apretar el botón "Subir CSV".
Una vez realizada la carga exitosa del csv, se sugiere comprobar la subida de los datos mediante el siguiente comando en la terminal:

aws dynamodb query \
    --table-name componentes \
    --index-name precio-index \
    --key-condition-expression "partType = :partition_value AND precio_ficticio = :precio_value" \
    --expression-attribute-values '{
        ":partition_value": {"S": "gpu"},
        ":precio_value": {"S": "350.0"}
    }'
