#!/bin/env python3
from pathlib import Path

from cassandra.cluster import Cluster
from cassandra import ConsistencyLevel


class App:
    def __init__(self):
        self.cluster = Cluster(contact_points=["scylla-node1", "scylla-node2", "scylla-node3"])
        self.session = self.cluster.connect(keyspace="catalog")
        self.session.default_consistency_level = ConsistencyLevel.QUORUM
        self.insert_ps = self.session.prepare(
            query="INSERT INTO mutant_data (first_name,last_name,address,website,picture_file) VALUES (?,?,?,?,?)"
        )
        self.delete_ps = self.session.prepare(query="DELETE FROM mutant_data WHERE first_name = ? and last_name = ?")
        self.get_pic_ps = self.session.prepare(
            query="SELECT picture_file FROM mutant_data WHERE first_name = ? and last_name = ?"
        )

    def show_mutant_data(self):
        print("Data that we have in the catalog".center(50, "="))
        result = self.session.execute(query="SELECT * FROM mutant_data")
        for row in result:
            print(f"{row.first_name} {row.last_name} <{list(row.picture_file.keys())[0]}")
        print("=" * 50)

    def add_mutant(self, first_name, last_name, address, website, picture_file):
        print(f"\nAdding {first_name} {last_name} with picture <{picture_file}>...")
        with open(picture_file, "rb") as mutant_pic:
            data = mutant_pic.read()
            self.session.execute(query=self.insert_ps,
                                 parameters=[first_name, last_name, address, website, {picture_file: data}])
        print("Added.\n")

    def save_mutant_photo(self, first_name, last_name, directory=Path("/tmp")):
        print(f"Saving {first_name} {last_name} picture to file...")
        result = self.session.execute(query=self.get_pic_ps, parameters=[first_name, last_name])
        mutant_photos = list(result)[0][0]
        for file_name, picture in mutant_photos.items():
            dest_dir = directory / file_name
            print(f"Saving to <{dest_dir}>")
            with dest_dir.open("wb") as file:
                file.write(picture)
            print("Done.")

    def delete_mutant(self, first_name, last_name):
        print(f"\nDeleting {first_name} {last_name}...")
        self.session.execute(query=self.delete_ps, parameters=[first_name, last_name])
        print("Deleted.\n")

    def stop(self):
        self.cluster.shutdown()


if __name__ == "__main__":
    app = App()
    app.add_mutant(first_name='Peter', last_name='Parker', address='1515 Main St',
                   website='http://www.facebook.com/Peter-Parker/', picture_file="peter_parker.jpg")
    app.add_mutant(first_name='Maximus', last_name='Lobo', address='New York, Lobo Technologies',
                   website='https://en.wikipedia.org/wiki/Maximus_Lobo', picture_file="maximus_lobo.png")
    app.show_mutant_data()
    app.save_mutant_photo(first_name="Peter", last_name="Parker")
    app.save_mutant_photo(first_name="Maximus", last_name="Lobo")
    app.delete_mutant(first_name="Peter", last_name="Parker")
    app.delete_mutant(first_name="Maximus", last_name="Lobo")
    app.stop()
