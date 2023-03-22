import { Component, OnInit } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { NotesRESTService } from 'src/app/services/notes-rest.service';
import { environment } from 'src/environments/environment';

@Component({
  selector: 'app-note-details',
  templateUrl: './note-details.page.html',
  styleUrls: ['./note-details.page.scss'],
})
export class NoteDetailsPage implements OnInit {

  note: any | null = null;

  constructor(
    private route: ActivatedRoute,
    private notesRESTService: NotesRESTService
  ) {}

  ngOnInit() {
    const id = this.route.snapshot.paramMap.get('id') || "";
    console.log(id)
    this.notesRESTService.getNoteDetails(id).subscribe((res) => {
      this.note = res;
//      console.log(this.note);
//console.log("Details loaded");
    });
  }

}
