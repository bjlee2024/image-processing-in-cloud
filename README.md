![alt text](image.png)

1. User 는 S3 에 src 이미지를 업로드
2. User 는 아래와 같은 형식으로 API 서버 호출

```json
{
// 업로드한 소스가 있는 폴더의 S3 URI
  "Source Folder Path": "s3://pointcloud.test.until.20240607/test/src",
// 처리결과가 저장되는 폴더의 S3 URI
  "Target Folder Path": "s3://pointcloud.test.until.20240607/test/target",
  "Force Global Align": true,
  "Save Source To Result Folder": true,
  "Complete Type": 1,
  "File Size": 1,
  "Use GPU": true,
  "Use GPU For Voxel Regeneration": true,
  "Compensate Occlusion Align": true,
  "Compensate Occlusion Level": 1,
  "Reduce Roughness": 0,
  "High Resolution Merge Type": 1,
  "Apply High Resolution to Prep": true
}
```

3. API 서버는 요청을 아래와 같이 Custom AMI 환경에 맞게 변환 후 S3 로 부터 소스 다운로드 및 이미지 프로세싱 처리
```json
{
// EC2 Instance 환경의 소스 경로
  "Source Folder Path": "C:\\Metdit_AutoTest\src",
// EC2 Instance 환경의 결과 파일이 저장되는 경로
  "Target Folder Path": "C:\\Medit_AutoTest\target",

// 아래 나머지 설정은 요청바디로 동일
  "Force Global Align": true,
  "Save Source To Result Folder": true,
  "Complete Type": 1,
  "File Size": 1,
  "Use GPU": true,
  "Use GPU For Voxel Regeneration": true,
  "Compensate Occlusion Align": true,
  "Compensate Occlusion Level": 1,
  "Reduce Roughness": 0,
  "High Resolution Merge Type": 1,
  "Apply High Resolution to Prep": true
}
```
4. EC2 로컬에 저장된 결과를 요청된 결과 S3 위치로 업로드

---
Description: This script is used to create a Flask API for pointcloud image processing tasks.
The API has the following endpoints:
1. POST /process: This endpoint is used to start a new image processing task. The request body should contain a JSON object with the following keys
   - "Source Folder Path": S3 URI of the source folder containing the images to be processed
   - "Target Folder Path": S3 URI of the target folder where the processed images will be saved
   - Other configuration parameters required for the image processing task
   The endpoint returns a JSON response with the job ID and status "started"
2. GET /job/<job_id>: This endpoint is used to get the status of a specific job identified by the job ID
   The endpoint returns a JSON response with the job ID and its status
3. GET /jobs: This endpoint is used to get the status of all active jobs
   The endpoint returns a JSON response with a list of job IDs and their statuses
4. GET /status/health: This endpoint is used for AWS EC2 Health Check
   The endpoint returns a JSON response with the status "ready"
---
검토 결과
1. TBD

