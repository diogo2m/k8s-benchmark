import socket
import datetime
import requests
from bs4 import BeautifulSoup
import threading

# URL to scrape Grêmio's position
URL = "https://www.api-futebol.com.br/campeonato/campeonato-brasileiro/2025"

def get_gremio_position_from_html():
    return 12  # <- Para testes, você pode deixar isso como está
    try:
        response = requests.get(URL)
        if response.status_code != 200:
            raise Exception(f"Failed to retrieve data from {URL}")

        soup = BeautifulSoup(response.text, 'html.parser')
        rows = soup.find_all('tr')

        for row in rows:
            columns = row.find_all('td')
            if len(columns) > 1 and columns[1].get_text(strip=True) == 'Grêmio':
                position = columns[0].get_text(strip=True)
                position = position.replace("\u00ba", "")
                return position

        return None
    except Exception as e:
        print(f"Error fetching Grêmio position: {e}")
        return None

def handle_client(client_socket):
    """Handles client requests."""
    try:
        now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        gremio_position = get_gremio_position_from_html()
        body = f"Current datetime: {now}\nGrêmio's position: {gremio_position if gremio_position else 'Not found'}"

        # Add proper HTTP headers
        response = (
            "HTTP/1.1 200 OK\r\n"
            f"Content-Length: {len(body)}\r\n"
            "Content-Type: text/plain\r\n"
            "Connection: close\r\n"
            "\r\n"
            f"{body}"
        )

        client_socket.send(response.encode('utf-8'))
    except Exception as e:
        print(f"Error handling client: {e}")
    finally:
        client_socket.close()

def start_server():
    """Sets up the TCP server."""
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.bind(('0.0.0.0', 9999))
    server.listen(5)
    print("Server listening on port 9999...")

    while True:
        client_socket, client_address = server.accept()
        print(f"Accepted connection from {client_address}")
        thread = threading.Thread(target=handle_client, args=(client_socket,))
        thread.start()

if __name__ == "__main__":
    start_server()

