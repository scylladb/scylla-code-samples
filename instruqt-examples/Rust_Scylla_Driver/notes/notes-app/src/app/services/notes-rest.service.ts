import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from 'src/environments/environment';

export interface NoteResult {
  id: string;
  content: string;
  topic: string;
}

@Injectable({
  providedIn: 'root'
})
export class NotesRESTService {

  constructor(private http: HttpClient) {}

  getNotes(page = 1): Observable<NoteResult[]> {
    return this.http.get<NoteResult[]>(
      `${environment.baseUrl}/notes`
    ); //TODO THIS is a full scan, so it's not optimal, also we need proper paging from the REST API to feed the scroll list
  }

  getNoteDetails(id: string): Observable<any> {
    return this.http.get<NoteResult>(
      `${environment.baseUrl}/note/${id}`
    );
  }
}
