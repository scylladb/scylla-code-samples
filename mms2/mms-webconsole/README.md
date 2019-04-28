# The Mutant Monitoring Web Console

A simple web appllication in Node.js to view and manipulate the MMS console.

## Getting Started

First we will need to bring up the Scylla cluster. Modify ```docker-compose.yml``` and add the following line to the environment: section of scylla-node1:
```
- IMPORT=IMPORT
```

Now we can build and run the Scylla Cluster:

```
docker-compose build
docker-compose up -d
```
After roughly 60 seconds, the existing MMS data will be automatically imported and we can proceed.

To build and run the MMS Web Console:
```
cd mms-webconsole
docker build -t webconsole .
docker run -d --net=mms_web -p 80:80 --name webconsole webconsole
```

## Accessing the Web Console

The web console is accessible at  http://127.0.0.1

Once in, we need to alter the existing catalog.mutant_data table to add a blob column for storing images. To do this, click on click Keyspaces -> Alter. Wait 10 seconds.

## Viewing the Catalog

Click on Click on Mutant -> Catalog. Now you should be able to see all of the mutants in the system. Notice how there are no photos there? Time to change that!

## Adding Photos

When browsing the catalog, you should see that no images are displayed. Click on the empty image and then you can see more information about the mutants such as their tracking data. Click anywhere in that window to bring up a dialog window that will let you choose a photo to upload from your computer. 

 When the upload is complete, you will see the new photo on the bottom of that window.
 
 Click Mutant -> Catalog to see the photo
 
 Now you can proceed to change the rest of the photos.
