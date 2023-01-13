begin transaction;

drop schema if exists Bibliotheque cascade;
create schema Bibliotheque;
set search_path to Bibliotheque;


create table Abonne (
  num_abonne serial,
  nom text not null,
  prenom text not null,
  num_civique integer not null,
  rue text not null,
  apt integer,
  ville text not null,
  code_postal varchar(6),
  primary key (num_abonne)
);

create table Livre (
  ISBN integer,
  titre text not null,
  genre text not null,
  annee_edition integer not null,
  editeur text not null,
  cote text not null,
  primary key (ISBN)
);

create table Auteur (
  num_auteur serial,
  prenom_auteur text not null,
  nom_auteur text not null,
  primary key (num_auteur)
);

create table Exemplaire (
  num_exemplaire serial, 
  ISBN integer, 
  primary key (num_exemplaire, ISBN),
  foreign key (ISBN) references Livre (ISBN) 
);

create table AuteurLivre (
  num_auteur serial,
  ISBN integer,
  primary key (num_auteur, ISBN),
  foreign key (num_auteur) references Auteur (num_auteur),
  foreign key (ISBN) references Livre (ISBN)
);

create table Emprunt (
  num_emprunt serial,
  ISBN integer,
  num_exemplaire integer,
  num_abonne integer,
  date_emprunt date not null,
  date_retour_prevu date not null,
  date_rendu date,
  montant_du decimal,
  primary key (num_emprunt),
  foreign key (ISBN, num_exemplaire) references Exemplaire (ISBN, num_exemplaire),
  foreign key (num_abonne) references Abonne (num_abonne),

  constraint empruntsk unique (ISBN, num_exemplaire, num_abonne, date_emprunt)
);

create table Commande (
  num_commande serial,
  ISBN integer,
  num_exemplaire integer,
  num_abonne integer,
  date_commande date,
  statut statut_commande,
  primary key (num_commande),
  foreign key (ISBN, num_exemplaire) references Exemplaire (ISBN, num_exemplaire),
  foreign key (num_abonne) references Abonne (num_abonne),
  constraint commandesk unique (ISBN, num_exemplaire, num_abonne, date_commande)
);


commit;
