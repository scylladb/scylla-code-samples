import { Component, OnInit } from '@angular/core';
import { InfiniteScrollCustomEvent, RefresherCustomEvent, LoadingController } from '@ionic/angular';
import { NotesRESTService } from 'src/app/services/notes-rest.service';
import { environment } from 'src/environments/environment';

 import { ViewWillEnter } from '@ionic/angular';

@Component({
  selector: 'app-notes',
  templateUrl: './notes.page.html',
  styleUrls: ['./notes.page.scss'],
})
export class NotesPage implements OnInit, ViewWillEnter  {
  notesData : any[] = [];
  currentPage = 1;

  constructor(
    private notesService: NotesRESTService,
    private loadingCtrl: LoadingController
  ) {
  }

  ngOnInit() {
    this.loadNotes();
  }

  async loadNotes(event?: InfiniteScrollCustomEvent) {
    const loading = await this.loadingCtrl.create({
      message: 'Loading..',
      spinner: 'bubbles',
    });
    await loading.present();

    this.notesService.getNotes(this.currentPage)
    .subscribe(
      (res) => {
        loading.dismiss();
        this.notesData=res;
//         console.log(this.notesData);
        console.log("Data loaded");
        event?.target.complete();
        if (event) { // since we don't have paging in REST app (and we don't know when to stop/how many notes there are), stop after first page
           event.target.disabled = 2 === this.currentPage;
        }
      },
      (err) => {
        console.log(err);
        loading.dismiss();
      }
    );
  }

  loadMore(event: InfiniteScrollCustomEvent) {
   this.currentPage++;
    this.loadNotes(event);
  }

  handleRefresh(event: RefresherCustomEvent ) {
    //console.log(event)
    this.loadNotes();
    console.log("refreshed")
    event.target.complete();
  }

 ionViewWillEnter() {
    console.log("navigate back")
    this.loadNotes();
  }

}
