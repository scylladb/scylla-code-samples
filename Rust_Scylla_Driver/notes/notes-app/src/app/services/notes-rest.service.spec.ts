import { TestBed } from '@angular/core/testing';

import { NotesRESTService } from './notes-rest.service';

describe('NotesRESTService', () => {
  let service: NotesRESTService;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(NotesRESTService);
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });
});
