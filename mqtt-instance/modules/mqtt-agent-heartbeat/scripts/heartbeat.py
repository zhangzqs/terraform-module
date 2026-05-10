#!/usr/bin/env python3
"""
Wait for MQTT Agent heartbeat to confirm agent readiness.

Reads JSON from stdin with:
- broker_host, broker_port, topic_prefix
- instance_id (node_id)
- terraform_private_key_pem, terraform_certificate_pem
- agent_certificate_pem
- timeout, poll_interval

Waits for heartbeat message on {topic_prefix}/{instance_id}/heartbeat,
verifies signature/encryption, and returns {"received": "true"} when first heartbeat arrives.
"""

import json
import sys
import time
import traceback
import ssl
from pathlib import Path

# Download/import paho-mqtt (same as agent.py)
try:
    import paho.mqtt.client as mqtt
except ImportError:
    import urllib.request
    import zipfile
    import site
    
    print("paho-mqtt not found, installing from PyPI...", file=sys.stderr)
    sys.stderr.flush()
    
    url = "https://files.pythonhosted.org/packages/50/13/2c5b1209534abdf150a92f5e3a8577285d1b3cf61267b1b1b88a5f9f53e5/paho-mqtt-1.6.1.tar.gz"
    
    import tarfile
    import tempfile
    import shutil
    
    tmpdir = tempfile.mkdtemp()
    try:
        tar_path = f"{tmpdir}/paho.tar.gz"
        urllib.request.urlretrieve(url, tar_path)
        extract_dir = f"{tmpdir}/extract"
        
        with tarfile.open(tar_path, "r:gz") as tar:
            tar.extractall(extract_dir)
        
        src = f"{extract_dir}/paho-mqtt-1.6.1/src/paho"
        dst = f"{site.getsitepackages()[0]}/paho"
        if Path(dst).exists():
            shutil.rmtree(dst)
        shutil.copytree(src, dst)
    finally:
        shutil.rmtree(tmpdir)
    
    import paho.mqtt.client as mqtt

sys.path.insert(0, Path(__file__).parent.parent / 'shared')
from mqtt_crypto import unpack_message

def main():
    data = json.loads(sys.stdin.read())
    
    broker_host = data["broker_host"]
    broker_port = int(data["broker_port"])
    topic_prefix = data["topic_prefix"]
    instance_id = data["instance_id"]
    timeout = int(data["timeout"])
    poll_interval = float(data["poll_interval"])
    
    terraform_private_key_pem = data["terraform_private_key_pem"]
    terraform_certificate_pem = data["terraform_certificate_pem"]
    agent_certificate_pem = data["agent_certificate_pem"]
    
    heartbeat_topic = f"{topic_prefix}/{instance_id}/heartbeat"
    
    heartbeat_received = {"flag": False, "message": None}
    
    def on_connect(client, userdata, flags, rc):
        if rc != 0:
            print(f"Connection failed with code {rc}", file=sys.stderr)
            return
        client.subscribe(heartbeat_topic)
    
    def on_message(client, userdata, msg):
        try:
            payload = msg.payload.decode('utf-8')
            message = unpack_message(
                payload,
                terraform_private_key_pem=terraform_private_key_pem,
                terraform_certificate_pem=terraform_certificate_pem,
                agent_certificate_pem=agent_certificate_pem
            )
            
            if message and message.get("message_type") == "heartbeat":
                heartbeat_received["flag"] = True
                heartbeat_received["message"] = message
                client.disconnect()
        except Exception as e:
            print(f"Error processing heartbeat: {e}", file=sys.stderr)
            traceback.print_exc(file=sys.stderr)
    
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1, client_id="terraform-heartbeat-waiter")
    client.on_connect = on_connect
    client.on_message = on_message
    
    # Setup TLS
    cafile = None
    client.tls_set(ca_certs=cafile, certfile=terraform_certificate_pem, keyfile=terraform_private_key_pem,
                   cert_reqs=ssl.CERT_NONE, tls_version=ssl.PROTOCOL_TLSv1_2, ciphers=None)
    client.tls_insecure_set(True)
    
    try:
        client.connect(broker_host, broker_port, keepalive=60)
        client.loop_start()
        
        start_time = time.time()
        while not heartbeat_received["flag"]:
            elapsed = time.time() - start_time
            if elapsed > timeout:
                raise TimeoutError(f"Heartbeat not received within {timeout}s")
            
            time.sleep(poll_interval)
        
        client.loop_stop()
        
        # Return success
        print(json.dumps({"received": "true", "status": "heartbeat confirmed"}))
        return 0
    
    except Exception as e:
        print(json.dumps({
            "error": str(e),
            "status": "heartbeat wait failed"
        }))
        return 1

if __name__ == "__main__":
    sys.exit(main())
