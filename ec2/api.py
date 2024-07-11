from flask import Flask, request, jsonify
import json
import boto3
import os
import subprocess
import time
import logging
from logging.handlers import TimedRotatingFileHandler
import threading

app = Flask(__name__)

s3 = boto3.client("s3")
cloudwatch = boto3.client('cloudwatch')

# 로깅 설정
log_dir = "C:\\MeditAutoTest\\logs"
os.makedirs(log_dir, exist_ok=True)
log_file = os.path.join(log_dir, "image_processing.log")

logger = logging.getLogger("ImageProcessing")
logger.setLevel(logging.INFO)
handler = TimedRotatingFileHandler(log_file, when="midnight", interval=1, backupCount=7)
formatter = logging.Formatter("%(asctime)s - %(name)s - %(levelname)s - %(message)s")
handler.setFormatter(formatter)
logger.addHandler(handler)

# 작업 상태를 저장할 딕셔너리
job_status = {}

def download_from_s3(s3_uri, local_path):
    bucket_name = s3_uri.split("/")[2]
    key = "/".join(s3_uri.split("/")[3:])
    s3.download_file(bucket_name, key, local_path)
    logger.info(f"Downloaded {s3_uri} to {local_path}")

def upload_to_s3(local_path, s3_uri):
    bucket_name = s3_uri.split("/")[2]
    key = "/".join(s3_uri.split("/")[3:])
    s3.upload_file(local_path, bucket_name, key)
    logger.info(f"Uploaded {local_path} to {s3_uri}")

def process_images(job_id, config):
    try:
        logger.info(f"Starting image processing task for job {job_id}")
        job_status[job_id] = "processing"

        source_s3_uri = config["Source Folder Path"]
        target_s3_uri = config["Target Folder Path"]

        local_source_path = f"C:\\MetditAutoTest\\src_{job_id}"
        download_from_s3(source_s3_uri, local_source_path)

        config["Source Folder Path"] = local_source_path
        config["Target Folder Path"] = f"C:\\MeditAutoTest\\target_{job_id}"
        
        with open(f"C:\\MetditAutoTest\\src_{job_id}\\config.json", "w") as f:
            json.dump(config, f)

        command = f"C:\\MeditAutoTest\\9999.0.0.4515_Release\\Medit_AutoTest.exe --iScanComplete 'C:\\MetditAutoTest\\src_{job_id}\\config.json'"
        logger.info(f"Running command: {command}")

        start_time = time.time()
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)

        for line in process.stdout:
            logger.info(line.decode().strip())
        for line in process.stderr:
            logger.error(line.decode().strip())

        process.wait()
        end_time = time.time()

        upload_to_s3(f"C:\\MeditAutoTest\\target_{job_id}", target_s3_uri)

        duration = end_time - start_time
        logger.info(f"Image processing completed in {duration:.2f} seconds for job {job_id}")
        
        # process_images 함수 내부, duration 계산 후
        cloudwatch.put_metric_data(
            Namespace='CustomMetrics',
            MetricData=[
                {
                    'MetricName': 'ProcessingDuration',
                    'Value': duration,
                    'Unit': 'Seconds'
                },
            ]
        )

        job_status[job_id] = "completed"
    except Exception as e:
        logger.error(f"Error processing job {job_id}: {str(e)}")
        job_status[job_id] = "failed"

@app.route('/process', methods=['POST'])
def start_processing():
    config = request.json
    job_id = str(int(time.time()))  # 간단한 작업 ID 생성
    threading.Thread(target=process_images, args=(job_id, config)).start()
    return jsonify({"job_id": job_id, "status": "started"}), 202

@app.route('/job/<job_id>', methods=['GET'])
def get_job_status(job_id):
    status = job_status.get(job_id, "not_found")
    return jsonify({"job_id": job_id, "status": status})

@app.route('/status/health', methods=['GET'])
def get_health_status():
    return jsonify({"status": "ready"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)