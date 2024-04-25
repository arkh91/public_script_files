from flask import Flask, jsonify, request, render_template

app = Flask(__name__)

@app.route('/')
def index():
    # Here you would typically load and display your Outline keys and their usage
    return render_template('index.html')

# Example of an endpoint to update keys (pseudo-code)
@app.route('/update_keys', methods=['POST'])
def update_keys():
    key_id = request.form['key_id']
    new_value = request.form['new_value']
    # Logic to update the key
    return jsonify({'status': 'success'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
