from flask import Flask, jsonify

app = Flask(__name__)


@app.get("/")
def health():
    return jsonify({
        "application": "python-migration-sample",
        "status": "ok"
    })


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
