import datetime

def main():
    # Imprimir mensaje de éxito
    print("El script se está ejecutando correctamente en la EC2 backend.")
    
    # Imprimir la fecha y hora actual
    now = datetime.datetime.now()
    print(f"Fecha y hora de ejecución: {now}")

if __name__ == "__main__":
    main()
