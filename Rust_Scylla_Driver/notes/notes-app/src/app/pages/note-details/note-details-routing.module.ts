import { NgModule } from '@angular/core';
import { Routes, RouterModule } from '@angular/router';

import { NoteDetailsPage } from './note-details.page';

const routes: Routes = [
  {
    path: '',
    component: NoteDetailsPage
  }
];

@NgModule({
  imports: [RouterModule.forChild(routes)],
  exports: [RouterModule],
})
export class NoteDetailsPageRoutingModule {}
