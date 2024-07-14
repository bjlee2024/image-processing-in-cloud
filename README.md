prototype architecture



work flow

User uploads source files(over 500MB) to be processed to src folder of S3 bucket

User calls rest api to start processing with some information like the below

{
// S3 URI for the uploaded source folder
  "Source Folder Path": "s3://pointcloud.test.until.20240607/test/src",
// S3 URI for output of processing
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

First Lambda receives user request and validates it ( if S3 URI is valid or not..) and adds it to SQS

Second Lambda receives SQS event and process task like the followings

Send command to EC2 instance thru AWS SSM

this command will run python script on EC2 with request body

In “process_image.py” on EC2 instance, 

replace two field of the above request body with local path like the below.

save the updated json as named “config.json” in local src folder

run command to process 3d image

our AMI has environments to run the following command

"C:\\MeditAutoTest\\9999.0.0.4515_Release\\Medit_AutoTest.exe --iScanComplete 'C:\\MetditAutoTest\\src\\config.json'"

send stdout, stderr and process time should be sent to cloudwatch

{
// Replaced with local path based on EC2 Instance Env
  "Source Folder Path": "C:\\MetditAutoTest\src",
// Replaced with local path based on EC2 Instance Env
  "Target Folder Path": "C:\\MeditAutoTest\target",

// the followings is same with original req
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



