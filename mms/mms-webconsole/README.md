# The Mutant Monitoring Web Console

A simple web appllication in Node.js to view and manipulate the MMS console.

## Getting Started

```
cd mms-webconsole
docker build -t webconsole .
docker run -d --net=mms_web -p 80:80 --name webconsole webconsole
```

## Accessing the Web Console

The web console is accessible at  http://127.0.0.1

Once in, we need to alter the existing catalog.mutant_data table to add a column for storing image. To do this, click on click Keyspaces -> Alter. Wait 10 seconds.

## Viewing the Catalog

Click on Click on Mutant -> Catalog. Now you should be able to see all of the mutants in the system. Notice how there are no photos there? Time to change that!

## Adding Photos

When browsing the catalog, you should see that no images are displayed. Click on the empty image and then you can see more information about the mutants such as their tracking data. Click anywhere in that window to bring up a dialog window that will let you choose a photo to upload from your computer. 

 When the upload is complete, you will see the new photo on the bottom of that window.
 
 Click Mutant -> Catalog to see the photo
 
 Now you can proceed to change the rest of the photos.
