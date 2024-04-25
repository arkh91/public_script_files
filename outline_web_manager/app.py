import requests
from flask import Flask, render_template

app = Flask(__name__)

API_URL = 'http://your-outline-server-address:port/api'

@app.route('/')
def index():
    keys = get_keys()
    return render_template('index.html', keys=keys)

def get_keys():
    response = requests.get(f"{API_URL}/keys")
    if response.status_code == 200:
        return response.json()
    else:
        return []

@app.route('/update_key', methods=['POST'])
def update_key():
    key_id = request.form['key_id']
    new_name = request.form['new_name']
    response = requests.put(f"{API_URL}/keys/{key_id}", json={'name': new_name})
    return jsonify(response.json())

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)


#wget https://raw.githubusercontent.com/arkh91/public_script_files/main/outline_web_manager/app.py
