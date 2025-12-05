#!/usr/bin/env python3
"""
Flask API for Docker stats monitoring
Runs on host (not containerized)
Listens on localhost:5000
"""

from flask import Flask, jsonify
import subprocess
import json
import sys

app = Flask(__name__)

@app.route('/docker-stats')
def get_docker_stats():
    """
    Get Docker container statistics
    Returns JSON array of container stats
    """
    try:
        # Run docker stats command
        result = subprocess.run(
            ["docker", "stats", "--format", "{{ json . }}", "--no-stream"],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode != 0:
            return jsonify({
                "error": "Failed to get docker stats",
                "message": result.stderr
            }), 500
        
        # Parse JSON lines
        stats = []
        for line in result.stdout.strip().splitlines():
            if line.strip():
                try:
                    # Parse JSON from each line
                    stat = json.loads(line)
                    stats.append(stat)
                except json.JSONDecodeError:
                    # Skip invalid JSON lines
                    continue
        
        return jsonify(stats)
    
    except subprocess.TimeoutExpired:
        return jsonify({
            "error": "Timeout getting docker stats"
        }), 500
    except Exception as e:
        return jsonify({
            "error": "Error getting docker stats",
            "message": str(e)
        }), 500

@app.route('/health')
def health_check():
    """
    Health check endpoint
    """
    return jsonify({
        "status": "healthy",
        "service": "flask-api"
    })

if __name__ == '__main__':
    # Run on localhost only (not 0.0.0.0)
    # Port can be overridden via environment variable
    import os
    port = int(os.environ.get('FLASK_API_PORT', 5000))
    app.run(host='localhost', port=port, debug=False)

