
begin transaction;

drop schema if exists Bibliotheque cascade;
create schema Bibliotheque;
set search_path to Bibliotheque;


SET client_encoding TO 'UTF8';

create table Abonne (
  num_abonne serial,
  prenom text not null,
  nom text not null,
  num_civique integer not null,
  rue text not null,
  apt integer,
  ville text not null,
  code_postal varchar(7),
  primary key (num_abonne)
);

create table Livre (
  ISBN bigint,
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
  num_exemplaire integer, --ne sera pas auto_increment
  ISBN bigint, 
  primary key (num_exemplaire, ISBN),
  constraint isbn_Ex foreign key (ISBN) references Livre (ISBN) on delete cascade on update cascade
);

create table AuteurLivre (
  num_auteur integer,
  ISBN bigint,
  primary key (num_auteur, ISBN),
  constraint aut_livre_AL foreign key (num_auteur) references Auteur (num_auteur) on delete cascade on update cascade,
  constraint isbn_AL foreign key (ISBN) references Livre (ISBN) on delete cascade on update cascade
);

create table Emprunt (
  num_emprunt serial,
  ISBN bigint,
  num_exemplaire integer,
  num_abonne integer,
  date_emprunt date default current_date,
  date_retour_prevu date default current_date + interval '14' day,
  date_rendu date default null,
  montant_du decimal default 0,
  primary key (num_emprunt),
  constraint isbn_ex_Emp foreign key (ISBN, num_exemplaire) references Exemplaire (ISBN, num_exemplaire) on delete cascade on update cascade,
  constraint ab_Emp foreign key (num_abonne) references Abonne (num_abonne) on delete cascade on update cascade,
  constraint sk_Emp unique (ISBN, num_exemplaire, num_abonne, date_emprunt),
  constraint jours_Emp check (date_retour_prevu > date_emprunt),
  constraint date_Emp check (date_rendu > date_emprunt)
);


create type statut_commande as enum ('annulee', 'honoree', 'active');

create table Commande (
  num_commande serial,
  ISBN bigint,
  num_exemplaire integer,
  num_abonne integer,
  date_commande date,
  statut statut_commande default 'active',
  primary key (num_commande),
  constraint isbn_ex_Com foreign key (ISBN, num_exemplaire) references Exemplaire (ISBN, num_exemplaire) on delete cascade on update cascade,
  constraint ab_Com foreign key (num_abonne) references Abonne (num_abonne) on delete cascade on update cascade,
  constraint sk_Com unique (ISBN, num_exemplaire, num_abonne, date_commande)
);



--Le même document ne peut pas être emprunté deux fois au même moment
create unique index unique_ex_Emp on Emprunt (ISBN, num_exemplaire) where (date_rendu is null);


--TRIGGERS ET FONCTIONS

--Nombre maximal d'emprunts par abonné
create or replace function max_emprunts()
  returns trigger as 
  $body$
  begin
    if (select count(*) from emprunt where emprunt.num_abonne=new.num_abonne and date_rendu is null) >= 10
    then
      raise exception 'Nombre maximal d''emprunts atteint.';
    end if;
    return new;
  end;
  $body$
  language plpgsql;

create trigger trigger_max_emprunts
  before INSERT ON emprunt
  for each row execute procedure max_emprunts();


--Nombre maximal de commandes actives par abonné
create or replace function max_commandes()
  returns trigger as 
  $body$
  begin
    if (select count(*) from commande where commande.num_abonne=new.num_abonne and statut='active') >= 3
    then
      raise exception 'Nombre maximal de commandes atteint.';
    end if;
    return new;
  end;
  $body$
  language plpgsql;

create trigger trigger_max_commandes
  before INSERT ON commande
  for each row execute procedure max_commandes();

--On ne peut pas commander un document qui est déjà disponible.
create or replace function empecher_commande()
  returns trigger as 
  $body$
  begin
    --si c'est une nouvelle commande et qu'il n'existe pas d'enregistrement qui montre que le document est sorti (->date_rendu is null)
    if new.statut='active' and not exists (select * from emprunt where emprunt.isbn=new.isbn and emprunt.num_exemplaire=new.num_exemplaire and emprunt.date_rendu is null)
    then
      raise exception 'On ne peut pas commander un document deja disponible. Veuillez l''emprunter.';
    end if;
    return new;
  end;
  $body$
  language plpgsql;

create trigger trigger_empecher_commande
  before INSERT ON commande
  for each row execute procedure empecher_commande();






--Calcul d'une amende pour retard
create or replace function calcul_amende()
  returns trigger as 
  $body$
  declare 
    diff_date integer := 0;
    frais_quot decimal := 0.5; --frais quotidiens pour retard
    amende decimal := 0;

  begin

    if old.date_rendu is null then
      diff_date = date_part('day', new.date_rendu) - date_part('day',new.date_retour_prevu);

     if diff_date > 0 then --si le livre est en retard
        amende = frais_quot * diff_date;
        update emprunt set montant_du = (old.montant_du+amende) where num_emprunt=new.num_emprunt;

      end if;

    end if;

    return new;

  end;
  $body$
  language plpgsql;

create trigger trigger_calcul_amende
  after UPDATE ON emprunt
  for each row execute procedure calcul_amende();








--INSERTIONS

insert into Abonne (prenom, nom, num_civique, rue, apt, ville, code_postal) values
  ('Virginie', 'Boulanger', 551, 'Boulevard Queen', NULL, 'Saint-Lambert', 'J4R 1J6'),
  ('Eric', 'Treves', 2104, 'Rue Nancy', NULL, 'Brossard', 'J4Y 1A6'),
  ('Alex', 'Dubois', 1888, 'Rue de Namur', NULL, 'Laval', 'H7M 4L8'),
  ('Stéphanie', 'Deschamps', 2145, 'Rue de Calmar', NULL, 'Laval', 'H7M 5S8'),
  ('Francis', 'Jornot', 4641, 'Boulevard Queen Saint Laurent', 3, 'Montréal', 'H2T 1R2'),
  ('Elise', 'Delpierre', 7067, 'Avenue Papineau', 12, 'Montréal', 'H2E 2G3'),
  ('Chris', 'Wright', 29, 'Avenue Forden', NULL, 'Westmount', 'H3Y 2Y6'),
  ('Magalie', 'Branson', 153, 'Rue Saint-Philippe', 5, 'Montréal', 'H4C 2T8'),
  ('Robert', 'Branson', 153, 'Rue Saint-Philippe', 5, 'Montréal', 'H4C 2T8'),
  ('Ella', 'Tran', 1329, 'Rue Paxton', 32, 'Montréal', 'H3J 2Z9'),
  ('Stéphane', 'Boulanger', 4830, 'Rue Hochelaga', 8, 'Montréal', 'H1V 3V7'),
  ('Samir', 'El-Habib', 7252, 'Rue de Candiac', NULL, 'Montreal', 'H1S 2E8'),
  ('Nesrine', 'Akrouf', 5930, 'Rue Boyer', NULL, 'Montreal', 'H2S 2H9'),
  ('Ramiro', 'Gomez', 1104, 'Rue Saint-Zotique E', NULL, 'Montreal', 'H2S 2H1'),
  ('Carolina', 'Ramirez', 4210, 'Avenue Kensington', NULL, 'Montréal', 'H4B 2W1');

insert into Livre (ISBN, titre, genre, annee_edition, editeur, cote) values 

  (9780133970777, 'Fundamentals of database systems', 'Informatique', 2016, 'Pearson', 'QA 7691 E44'),
  (9780805317558, 'Fundamentals of database systems', 'Informatique', 1999, 'Addison Wesley Publishing Company', 'QA 7619 E44'),
  (9782253160885, 'Les enfants du capitaine Grant', 'Roman', 2007, 'Librairie générale française', 'PQ 2469 E55'),
  (9782013214629, 'L''île mystérieuse', 'Roman', 1996, 'Hachette Livre', 'PQ 2469 A01' ),
  (9782258089310, 'À la recherche du temps perdu', 'Philosophie', 2001, 'Omnibus', 'PQ 2631 R63'),
  (9782226448453, 'Sapiens', 'Historique', 2020, 'Paris : Michel Albin', 'PN 6790 I77'),
  (9782226436030, '21 lessons for the 21st century', 'Prévision', 2018, 'Michel Albin', 'CB 4287 H37'),
  (9782226393876, 'Homo deus : une brève histoire de l''avenir', 'Historique', 2017, 'Michel Albin', 'CB 4281 H36'),
  (9782744023330, 'Programmation concurrente en Java', 'Informatique', 2009, 'Pearson', 'QA 7673 J38'),
  (9780321349606, 'Java Concurrency in Practice', 'Informatique', 2006, 'Addison-Wesley Professional', 'QA 5173 J38'),
  (9780375702242, 'The Idiot', 'Romans', 2003, 'Vintage', 'PQ 5167 K85'),
  (9781593080815, 'Crime And Punishment', 'Roman', 2007, 'Barnes & Noble Classics', 'PQ 98674 S15'),
  (9780191019753, 'Crime And Punishment', 'Roman', 2017, 'Oxford', 'PQ 98694 Y15'),
  (9781492084006, 'DevOps Tools for Java Developers', 'Informatique', 2021, 'Reilly Media, Inc.', 'QA 7413 M37'),
  (9781484230411, 'Pro JavaFX 9', 'Informatique', 2018, 'Apress', 'QA 8611 L74'),
  (9780030565816, 'The Long Walk to Freedom', 'Biographie', 2011, 'Little, Brown & Company', 'BG 1411 R21'),
  (9780759581425, 'The Long Walk to Freedom', 'Biographie',2000, 'Little, Brown & Company', 'BG 0154 F11'),
  (9782262068028, 'Churchill : stratège passionné', 'Biographie', 2017, 'PERRIN', 'BG 5175 M53'),
  (9781524763138, 'Becoming', 'Biographie', 2018, 'Random House of Canada', 'BG 6722 G13'),
  (9780393355628, 'Surely You''re Joking, Mr. Feynman!', 'Science', 2018, 'WW Norton', 'QC 1647 F49'),
  (9782290006450, 'Une brève histoire du temps : du big bang aux trous noirs', 'Science', 2007, 'J AI LU', 'QC 1017 D40'),
  (9782081404342, 'Une brève histoire du temps : du big bang aux trous noirs', 'Science', 2017, 'Flammarion,', 'QC 4537 E10'),
  (9782081214842, 'Une brève histoire du temps : du big bang aux trous noirs', 'Science', 2013, 'Flammarion,', 'QC 2948 S07'),
  (9783836500852, 'Kahlo', 'Art', 2015, 'TASCHEN', 'AT 2964 D47'),
  (9783836558075, 'Klimt', 'Art', 2020, 'TASCHEN', 'AT 5165 D78'),
  (9780072976755, 'Fundamentals of thermal-fluid sciences', 'Science', 2005, 'McGraw-Hill', 'TJ 265 C42'),
  (9780321965516, 'Don''t make me think, revisited: a common sense approach to Web usability', 'Informatique', 2014, 'New Riders', 'TK 5105.888 K78'),
  (9782070410835, 'Les fleurs bleues', 'Roman', 1999, 'Gallimard','PQ 2633 U43 F543');

  insert into Auteur (prenom_auteur, nom_auteur) values 
  ('Ramez', 'Elmasri'),
  ('Shamkant', 'Navathe'),
  ('Jules', 'Verne'),
  ('Marcel', 'Proust'), 
  ('Yuval', 'Harari'),
  ('David', 'Vandermeulen'),
  ('Brian', 'Goetz'),
  ('Tim', 'Peierls'),
  ('Joshua', 'Bloch'),
  ('Joseph', 'Bowbeer'), -- 10
  ('Fyodor', 'Dostoevsky'),
  ('Stephen', 'Chin'),
  ('Baruch', 'Sadogursky'),
  ('Melissa', 'McKay'),
  ('Ixchel', 'Ruiz'),
  ('Johan', 'Vos'),
  ('Weiqi', 'Gao'),
  ('James', 'Weaver'),
  ('Dean', 'Iverson'),
  ('Nelson', 'Mandela'), -- 20
  ('François', 'Kersaudy'),
  ('Michelle', 'Obama'),
  ('Richard', 'Feynman'),
  ('Stephen', 'Hawking'),
  ('Andrea', 'Kettenmann'),
  ('Gilles', 'Néret'), -- 26
  ('Yunus A.', 'Cengel'),
  ('Robert H.', 'Turner'),
  ('Steve', 'Krug'),
  ('Raymond', 'Queneau'); --30

  insert into Exemplaire (ISBN, num_exemplaire) values
  (9780133970777, 1),
  (9780133970777, 2),
  (9780133970777, 3),
  (9780805317558, 1),
  (9780805317558, 2),
  (9782253160885, 1),
  (9782253160885, 2),
  (9782013214629, 1),
  (9782258089310, 1),
  (9782258089310, 2),
  (9782258089310, 3),
  (9782226448453, 1),
  (9782226448453, 2),
  (9782226436030, 1), 
  (9782226393876, 1),
  (9782226393876, 2),
  (9782744023330, 1),
  (9780321349606, 1),
  (9780375702242, 1),
  (9781593080815, 1),
  (9781593080815, 2),
  (9781593080815, 3),
  (9780191019753, 1),
  (9781492084006, 1),
  (9781492084006, 2),
  (9781492084006, 3),
  (9781484230411, 1),
  (9781484230411, 2),
  (9780030565816, 1),
  (9780759581425, 1),
  (9782262068028, 1),
  (9782262068028, 2),
  (9781524763138, 1),
  (9780393355628, 1),
  (9782290006450, 1),
  (9782290006450, 2),
  (9782290006450, 3),
  (9782081404342, 1),
  (9782081214842, 2),
  (9783836500852, 1),
  (9783836558075, 1),
  (9780072976755, 1),
  (9780321965516, 1),
  (9780321965516, 2),
  (9780321965516, 3),
  (9780321965516, 4),
  (9782070410835, 1),
  (9782070410835, 2);

insert into AuteurLivre (num_auteur, ISBN) values
  (1, 9780133970777),
  (2, 9780133970777),
  (1, 9780805317558),
  (2, 9780805317558),
  (3, 9782253160885), 
  (3, 9782013214629),
  (4, 9782258089310),
  (5, 9782226448453), 
  (6, 9782226448453),
  (5, 9782226436030),
  (5, 9782226393876),
  (7, 9782744023330),
  (8, 9782744023330),
  (9, 9782744023330),
  (10, 9782744023330),
  (7, 9780321349606),
  (8, 9780321349606),
  (9, 9780321349606),
  (10, 9780321349606),
  (11, 9780375702242),
  (11, 9781593080815),
  (11, 9780191019753),
  (12, 9781492084006),
  (13, 9781492084006),
  (14, 9781492084006),
  (15, 9781492084006),
  (12, 9781484230411),
  (16, 9781484230411),
  (17, 9781484230411),
  (18, 9781484230411),
  (19, 9781484230411),
  (20, 9780030565816),
  (20, 9780759581425),
  (21, 9782262068028),
  (22, 9781524763138), 
  (23, 9780393355628),
  (24, 9782290006450),
  (24, 9782081404342),
  (24, 9782081214842),
  (25, 9783836500852),
  (26, 9783836558075),
  (27, 9780072976755),
  (28, 9780072976755),
  (29, 9780321965516),
  (30, 9782070410835);


--Emprunts passés
insert into emprunt (ISBN, num_exemplaire, num_abonne, date_emprunt, date_retour_prevu, date_rendu) values 
  (9780133970777, 1, 1, '2020-10-20', '2020-11-03', '2020-11-02'),
  (9780133970777, 2, 1, '2020-07-01', '2020-07-15', '2020-07-12'), 
  (9780133970777, 3, 1, '2018-07-14', '2018-07-28', '2018-07-30'), 
  (9780805317558, 1, 1, '2017-08-16', '2017-08-30', '2017-08-30'),
  (9780805317558, 2, 1, '2016-09-18', '2016-10-02', '2016-10-12'), 
  (9782253160885, 1, 1, '2015-10-03', '2015-10-17', '2015-10-23'), 
  (9782253160885, 2, 1, '2020-03-02', '2020-11-03', '2020-11-03');

  --Insertion de retards:
insert into emprunt (ISBN, num_exemplaire, num_abonne, date_emprunt, date_retour_prevu, date_rendu, montant_du) values 
  (9782070410835, 1, 6, '2017-08-11', '2017-08-25', '2017-08-28', 1.5),
  (9782070410835, 1, 9, '2017-02-05', '2017-02-09', '2017-03-20', 5.5);

--L'usager 1 a emprunté 4 documents:
insert into emprunt (ISBN, num_exemplaire, num_abonne, date_emprunt, date_retour_prevu, date_rendu) values 
  (9782013214629, 1, 1, '2021-03-22', '2021-04-05', null), 
  (9782258089310, 1, 1, '2021-04-10', '2021-04-24', null), 
  (9782258089310, 2, 1, '2021-04-10', '2021-04-24', null), 
  (9782262068028, 1, 1, '2021-04-10', '2021-04-24', null);


--L'usager 2 sort 10 documents:
 insert into emprunt (ISBN, num_exemplaire, num_abonne) values 
(9782258089310, 3, 2),
(9782226448453, 1, 2),
(9782226448453, 2, 2),
(9782226436030, 1, 2),
(9782226393876, 1, 2),
(9782226393876, 2, 2),
(9782744023330, 1, 2),
(9780321349606, 1, 2),
(9780375702242, 1, 2),
(9781593080815, 1, 2);


--Commandes de documents
insert into commande (ISBN, num_exemplaire, num_abonne, date_commande, statut) values 
(9782253160885, 1, 2, '2015-08-19', 'honoree'), 
(9780321965516, 4, 5, '2013-02-11', 'annulee'), 
(9780072976755, 1, 6, '2020-11-03', 'honoree'), 
(9783836558075, 1, 4, '2021-01-15', 'honoree'), 
(9783836500852, 1, 3, '2015-08-19', 'honoree'), 
(9782081404342, 1, 9, '2020-06-30', 'annulee'), 
(9782253160885, 1, 2, '2008-10-27', 'honoree'), 
(9782013214629, 1, 8, '2021-04-12', 'active'), 
(9782258089310, 1, 8, '2021-04-12', 'active'), 
(9782258089310, 2, 8, '2021-04-12', 'active');



--TESTS DES CONTRAINTES:

--Tentative d'emprunter un livre déjà emprunté:
--insert into emprunt (ISBN, num_exemplaire, num_abonne, date_emprunt) values (9780321349606, 1, 1, '2021-04-10');

--Nombre maximal de documents empruntés:
--insert into emprunt (ISBN, num_exemplaire, num_abonne) values (9781593080815, 2, 2);

--Nombre maximal de commandes:
--insert into commande (ISBN, num_exemplaire, num_abonne, date_commande, statut) values (9782262068028, 1, 8, '2021-04-12', 'active');

--Retour d'un livre en retard, calcul d'une amende:
--update emprunt set date_rendu = current_date where isbn=9782013214629 and num_exemplaire=1 and date_rendu is null; --donne une amende (retard 7 jours)
--update emprunt set date_rendu = current_date where isbn=9782258089310 and num_exemplaire=1 and date_rendu is null; --ne donne pas d'amende






--TÂCHE #5:
--Requêtes SQL de notre application:

-- Question 1
-- Quel est le nombre d'emprunts faits à partir du 1er janvier 2021 par genre de livre?
-- Trier les résultats par nombre de livres décroissant. 

with R1 as (select ISBN from Emprunt where Emprunt.date_emprunt >= '2021-01-01'),
     R2 as (select ISBN, genre from Livre),
     R3 as (select * from R1 natural join R2)
     select genre, count(genre) as nb_livres_genre from R3
     group by genre 
     order by nb_livres_genre desc;


-- Question 2
-- Quels sont les numéros, les prénoms et les noms d'abonné, qui ont fait plus d'une commande?
-- Trier les résultats par nombre de commandes croissant. 

with R1 as (select num_abonne, count(num_abonne) as nb_commandes from Commande 
            group by num_abonne),
     R2 as (select * from R1 
     group by num_abonne, nb_commandes
     having nb_commandes > 1
     order by nb_commandes asc)
     select num_abonne, prenom, nom, nb_commandes from Abonne natural join R2;


-- Question 3
-- Quels sont les emprunts rendus en retard? Afficher leur numéro, leur titre, leurs auteurs, le nom d'abonné avec un montant de pénalité.
-- Trier les résultats selon les jours de retard décroissants.

with R1 as (select num_emprunt, ISBN, num_abonne, (date_rendu - date_retour_prevu) as nb_jours_retard, montant_du from Emprunt
            group by num_emprunt
            having (date_rendu - date_retour_prevu) > 0),
     R2 as (select * from R1 natural join AuteurLivre),
     R3 as (select * from R2 natural join Auteur),
     R4 as (select * from R3 natural join Livre),
     R5 as (select * from R4 natural join Abonne)
     select num_emprunt, titre, 
     string_agg (prenom_auteur || ' ' || nom_auteur, '; ' order by prenom_auteur, nom_auteur, num_emprunt) as auteurs, 
     concat (prenom || ' ' || nom) as abonné, 
     nb_jours_retard, montant_du from R5
     group by num_emprunt, titre, prenom, nom, nb_jours_retard, montant_du
     order by nb_jours_retard desc;


-- Question 4
-- Quelle est la liste de livres que détient la bibliothèque? Afficher le nombre d'exemplaires pour chaque livre et 
-- trier les résultats selon les titres croissants.

with R1 as (select * from Livre natural join AuteurLivre),
     R2 as (select * from R1 natural join Auteur),
     R3 as (select ISBN, count(num_exemplaire) as nb_exemplaires from Exemplaire
            group by ISBN)
     select ISBN, titre, 
     string_agg (prenom_auteur || ' ' || nom_auteur, '; ' order by prenom_auteur, nom_auteur, ISBN) as auteurs, 
     genre, annee_edition, nb_exemplaires from R2 natural join R3
     group by ISBN, titre, genre, annee_edition, nb_exemplaires
     order by titre asc; 




commit;
