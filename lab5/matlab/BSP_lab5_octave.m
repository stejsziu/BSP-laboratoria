%% LAB 5 - System sterowania samolotu bezzałogowego  (wersja dla GNU Octave)
%  Generowanie wykresów (po polsku) i eksport do PDF przyciętych do wykresu.
%  Dane:  ./src   (obok skryptu)      Wyniki: ../raport/wykresy
%  Plik zapisz w UTF-8.
%
%  Układ kolumn w plikach danych (42 kolumny, 3 ostatnie nieopisane w instrukcji):
%   1 czas | 2-5 sygnały zadane (napęd[ms], lotki, wysokość, kierunek [rad])
%   6-9 sygnały symulowane | 10-12 pozycja x,y,z | 13-15 U,V,W | 16-18 ax,ay,az
%   19-21 Phi,Theta,Psi | 22-24 P,Q,R | 25 alfa | 26 beta | 27-39 pomiary | 40-42 ?

1;   % oznacza plik skryptowy (funkcje poniżej muszą być zdefiniowane PRZED użyciem)

%% ===================== FUNKCJE =====================

function D = wczytajDane(plik)
  % Pomija linie tekstowe (INFO, TIME, ...) i czyta tylko wiersze numeryczne
  txt   = fileread(plik);
  linie = regexp(txt, '\r?\n', 'split');
  ok    = ~cellfun('isempty', regexp(linie, '^\s*[-+]?\d*\.?\d+([eE][-+]?\d+)?\t', 'once'));
  C     = cellfun(@(s) sscanf(s, '%f')', linie(ok), 'UniformOutput', false);
  if isempty(C), error('Brak danych liczbowych w pliku %s', plik); end
  n = cellfun(@numel, C);
  C = C(n == mode(n));                        % odrzuć urwane wiersze
  D = vertcat(C{:});
  k = find(diff(D(:,1)) <= 0, 1, 'last');     % restart zapisu w trakcie pliku
  if ~isempty(k)
    warning('%s: czas się cofa - użyto ostatniego odcinka zapisu.', plik);
    D = D(k+1:end, :);
  end
end

function plik = znajdzPlik(folder, baza)
  % obsługa nazw typu: x.txt, x.txt.txt oraz "2traj2" zamiast "2_traj2"
  bazy = {baza, strrep(baza, '2_traj', '2traj')};
  ext  = {'.txt', '.txt.txt'};
  plik = '';
  for b = 1:numel(bazy)
    for e = 1:numel(ext)
      p = fullfile(folder, [bazy{b} ext{e}]);
      if exist(p, 'file') == 2, plik = p; return; end
    end
  end
end

function bieg = wczytajBieg(folder, baza, tmax)
  bieg = [];
  plik = znajdzPlik(folder, baza);
  if isempty(plik)
    warning('Nie znaleziono pliku dla: %s', baza);
    return
  end
  D = wczytajDane(plik);
  D(:,1) = D(:,1) - D(1,1);
  D = D(D(:,1) <= tmax, :);
  bieg.D = D;
  bieg.plik = plik;
end

function [e, t] = bladPozycji(Dref, Dbieg)
  % |r(t) - r_ref(t)| na siatce czasu lotu referencyjnego (do końca krótszego lotu)
  tmax = min(Dref(end,1), Dbieg(end,1));
  mk   = Dref(:,1) <= tmax;
  t    = Dref(mk, 1);
  [tu, iu] = unique(Dbieg(:,1));
  P    = interp1(tu, Dbieg(iu, 10:12), t, 'linear');
  e    = sqrt(sum((P - Dref(mk, 10:12)).^2, 2));
end

function ax = nowaOs(f, poz)
  ax = axes('Parent', f, 'Units', 'centimeters', 'Position', poz, ...
            'FontSize', 9, 'Box', 'on');
  hold(ax, 'on'); grid(ax, 'on');
end

function f = nowaFig()
  f = figure('Visible', 'off', 'Units', 'centimeters', 'Position', [2 2 30 30], ...
             'Color', 'w');
end

function zapisz(f, axs, plik, etyk, lokLeg, padCm)
  % Przycina rysunek do samych osi + opisów (TightInset), dodaje legendę i drukuje PDF.
  % axs - uchwyty osi w cm (od góry do dołu)
  drawnow;
  n = numel(axs);
  pos = zeros(n, 4);  ti = zeros(n, 4);
  for k = 1:n
    pos(k,:) = get(axs(k), 'Position');
    ti(k,:)  = get(axs(k), 'TightInset');
  end
  gora = ti(1,4);
  if ~isempty(etyk) && strcmp(lokLeg, 'north'), gora = gora + 0.75; end
  % TightInset w Octave nie uwzględnia w pełni opisów osi - dodajemy poprawki
  L = max(ti(:,1)) + 0.55 + padCm;
  B = ti(n,2) + 0.50 + padCm;                  % dolna oś ma opis osi X
  Rr = max(ti(:,3)) + 0.30 + padCm;
  T = gora + 0.30 + padCm;
  x0 = min(pos(:,1));  y0 = min(pos(:,2));
  W = max(pos(:,1) + pos(:,3)) - x0;
  H = max(pos(:,2) + pos(:,4)) - y0;
  set(f, 'Position', [2 2 L + W + Rr, B + H + T]);
  for k = 1:n
    set(axs(k), 'Position', [pos(k,1) - x0 + L, pos(k,2) - y0 + B, pos(k,3), pos(k,4)]);
  end
  if ~isempty(etyk)
    if strcmp(lokLeg, 'north')
      lg = legend(axs(1), etyk, 'Location', 'northoutside', 'Orientation', 'horizontal');
    else
      lg = legend(axs(1), etyk, 'Location', 'northeast');
    end
    set(lg, 'FontSize', 8);
  end
  p = get(f, 'Position');
  set(f, 'PaperUnits', 'centimeters');
  set(f, 'PaperSize', p(3:4));
  set(f, 'PaperPosition', [0 0 get(f, 'PaperSize')]);
  drawnow;
  print(f, plik, '-dpdf');
  close(f);
end

function wykresCzasowy(R, fy, ylab, plik, wys, pad)
  f  = nowaFig();
  ax = nowaOs(f, [2 2 12.5 wys]);
  for k = 1:numel(R)
    D = R{k}.D;
    plot(ax, D(:,1), fy(D), R{k}.ls, 'Color', R{k}.kol, 'LineWidth', 1.1);
  end
  xlabel(ax, 'Czas [s]');  ylabel(ax, ylab);
  tmax = 0;
  for k = 1:numel(R), tmax = max(tmax, R{k}.D(end,1)); end
  xlim(ax, [0 tmax]);
  zapisz(f, ax, plik, etykiety(R), 'inside', pad);
end

function panele(R, spec, plik, pad)
  m = size(spec, 1);
  hp = 3.0;  odstep = 0.35;  w = 12.5;
  f = nowaFig();
  axs = zeros(m, 1);
  tmax = 0;
  for k = 1:numel(R), tmax = max(tmax, R{k}.D(end,1)); end
  for p = 1:m
    y = 2 + (m - p) * (hp + odstep);
    ax = nowaOs(f, [2 y w hp]);
    for k = 1:numel(R)
      D = R{k}.D;
      plot(ax, D(:,1), spec{p,1}(D), R{k}.ls, 'Color', R{k}.kol, 'LineWidth', 1.1);
    end
    ylabel(ax, spec{p,2});
    xlim(ax, [0 tmax]);
    if p < m
      set(ax, 'XTickLabel', []);
    else
      xlabel(ax, 'Czas [s]');
    end
    axs(p) = ax;
  end
  zapisz(f, axs, plik, etykiety(R), 'north', pad);
end

function wykresXY(R, plik, pad)
  % y poziomo, x pionowo; skala 1:1 uzyskana przez dobranie proporcji osi
  xmin = Inf; xmax = -Inf; ymin = Inf; ymax = -Inf;
  for k = 1:numel(R)
    D = R{k}.D;
    xmin = min(xmin, min(D(:,10)));  xmax = max(xmax, max(D(:,10)));
    ymin = min(ymin, min(D(:,11)));  ymax = max(ymax, max(D(:,11)));
  end
  rx = max(xmax - xmin, 1);  ry = max(ymax - ymin, 1);
  rx = rx * 1.06;  ry = ry * 1.06;
  cx = (xmax + xmin) / 2;  cy = (ymax + ymin) / 2;
  s  = min(12.5 / ry, 11 / rx);                 % cm na metr
  w  = max(s * ry, 5);  h = max(s * rx, 4);
  ry = w / s;  rx = h / s;                      % równa skala po poszerzeniu osi
  f  = nowaFig();
  ax = nowaOs(f, [2 2 w h]);
  for k = 1:numel(R)
    D = R{k}.D;
    plot(ax, D(:,11), D(:,10), R{k}.ls, 'Color', R{k}.kol, 'LineWidth', 1.1);
  end
  xlim(ax, [cy - ry/2, cy + ry/2]);
  ylim(ax, [cx - rx/2, cx + rx/2]);
  xlabel(ax, 'Położenie y [m]');  ylabel(ax, 'Położenie x [m]');
  zapisz(f, ax, plik, etykiety(R), 'inside', pad);
end

function e = etykiety(R)
  if numel(R) > 1
    e = cell(1, numel(R));
    for k = 1:numel(R), e{k} = R{k}.etyk; end
  else
    e = {};
  end
end

function rysujZestaw(R, prefix, folderWyj, pad, specKaty, specZad, specSym)
  wykresXY(R, fullfile(folderWyj, [prefix '_trajektoria_xy.pdf']), pad);
  wykresCzasowy(R, @(D) -D(:,12), 'Wysokość [m]', ...
                fullfile(folderWyj, [prefix '_wysokosc.pdf']), 5.5, pad);
  panele(R, specKaty, fullfile(folderWyj, [prefix '_katy.pdf']), pad);
  panele(R, specZad,  fullfile(folderWyj, [prefix '_sterowanie_zadane.pdf']), pad);
  panele(R, specSym,  fullfile(folderWyj, [prefix '_sterowanie_symulowane.pdf']), pad);
end

%% ===================== KONFIGURACJA =====================
clear; clc; close all;

skryptDir = fileparts(mfilename('fullpath'));
if isempty(skryptDir), skryptDir = pwd; end

folderDane = fullfile(skryptDir, 'src');                     % pliki .txt
folderWyj  = fullfile(skryptDir, '..', 'raport', 'wykresy');

czasMax       = [Inf Inf];   % [s] obcięcie danych dla trajektorii 1 i 2 (np. [100 50])
oknoRownowagi = [0 Inf];     % [s] okno uśredniania parametrów równowagi (lot swobodny)
paddingCm     = 0.08;        % [cm] margines wokół wykresu w PDF

% Badania: id (do nazw plików), etykieta wariantu bazowego, warianty {sufiks pliku, etykieta}
grupy = struct('id', {}, 'baza', {}, 'war', {});
grupy(1).id = 'serwo'; grupy(1).baza = 'bez serwomechanizmów';
grupy(1).war = {'serwo10', 'prędkość serwa 10'; 'serwo90', 'prędkość serwa 90'};
grupy(2).id = 'luz';   grupy(2).baza = 'bez luzów';
grupy(2).war = {'luz1', 'luz 1%'; 'luz10', 'luz 10%'};
grupy(3).id = 'opoz';  grupy(3).baza = 'bez opóźnienia';
grupy(3).war = {'opoz01', 'opóźnienie 0,1 s'; 'opoz1', 'opóźnienie 1 s'};   % <- sprawdź wartości!
grupy(4).id = 'szum';  grupy(4).baza = 'bez szumów';
grupy(4).war = {'szum1', 'moc szumu 1'; 'szum10', 'moc szumu 10'};
grupy(5).id = 'czul';  grupy(5).baza = 'czułość AP = 1';
grupy(5).war = {'czul10', 'czułość AP = 10'};

kol    = [0 0 0; 0 0.447 0.741; 0.850 0.325 0.098; 0.466 0.674 0.188; 0.494 0.184 0.556];
styles = {'-', '--', '-.', ':', '-'};

%% ===================== PRZYGOTOWANIE =====================
if ~exist(folderWyj, 'dir'), mkdir(folderWyj); end
[st, info] = fileattrib(folderWyj);
if st == 1, folderWyj = info.Name; end                       % ścieżka bezwzględna
folderRaport = fileparts(folderWyj);

r2d = @(x) x * 180 / pi;

% definicje paneli: {funkcja licząca dane z macierzy D, opis osi Y}
specKaty = {@(D) r2d(D(:,19)),         'Przechylenie \Phi [^\circ]';
            @(D) r2d(D(:,20)),         'Pochylenie \Theta [^\circ]';
            @(D) r2d(unwrap(D(:,21))), 'Odchylenie \Psi [^\circ]'};
specZad  = {@(D) D(:,2),     'Napęd [ms]';
            @(D) r2d(D(:,3)), 'Lotki [^\circ]';
            @(D) r2d(D(:,4)), 'Ster wysokości [^\circ]';
            @(D) r2d(D(:,5)), 'Ster kierunku [^\circ]'};
specSym  = {@(D) D(:,6),     'Napęd [ms]';
            @(D) r2d(D(:,7)), 'Lotki [^\circ]';
            @(D) r2d(D(:,8)), 'Ster wysokości [^\circ]';
            @(D) r2d(D(:,9)), 'Ster kierunku [^\circ]'};
specRown = {@(D) sqrt(D(:,13).^2 + D(:,14).^2 + D(:,15).^2), 'Prędkość V [m/s]';
            @(D) r2d(D(:,25)),                               'Kąt natarcia \alpha [^\circ]';
            @(D) r2d(D(:,8)),                                'Ster wysokości [^\circ]'};

%% ===================== 1. LOT SWOBODNY =====================
sw = wczytajBieg(folderDane, '2_lot_swobodny', Inf);
if ~isempty(sw)
  R = {struct('D', sw.D, 'kol', kol(1,:), 'ls', '-', 'etyk', 'lot swobodny')};
  rysujZestaw(R, 'lot_swobodny', folderWyj, paddingCm, specKaty, specZad, specSym);
  panele(R, specRown, fullfile(folderWyj, 'lot_swobodny_rownowaga.pdf'), paddingCm);

  D = sw.D;  m = D(:,1) >= oknoRownowagi(1) & D(:,1) <= oknoRownowagi(2);
  V = specRown{1,1}(D);  al = specRown{2,1}(D);  dh = specRown{3,1}(D);
  fprintf('\n=== Parametry równowagi (lot swobodny, okno %.1f-%.1f s) ===\n', ...
          min(D(m,1)), max(D(m,1)));
  fprintf('Prędkość V            : %.3f m/s  (odch. std %.3f)\n', mean(V(m)),  std(V(m)));
  fprintf('Kąt natarcia alfa     : %.3f deg  (odch. std %.3f)\n', mean(al(m)), std(al(m)));
  fprintf('Wychylenie steru wys. : %.3f deg  (odch. std %.3f)\n', mean(dh(m)), std(dh(m)));
end

%% ===================== 2-5. LOTY AUTOMATYCZNE =====================
wyniki = cell(0, 5);

for tr = 1:2
  ref = wczytajBieg(folderDane, sprintf('2_traj%d_czul1', tr), czasMax(tr));
  if isempty(ref)
    warning('Trajektoria %d: brak lotu bazowego (czul1) - pomijam błędy pozycji.', tr);
  end

  for g = 1:numel(grupy)
    R = {};
    if ~isempty(ref)
      R{end+1} = struct('D', ref.D, 'kol', kol(1,:), 'ls', styles{1}, 'etyk', grupy(g).baza);
    end
    for i = 1:size(grupy(g).war, 1)
      w = grupy(g).war{i, 1};
      if strncmp(w, 'czul', 4)
        nazwa = sprintf('2_traj%d_%s', tr, w);
      else
        nazwa = sprintf('2_traj%d_czul1_%s', tr, w);
      end
      b = wczytajBieg(folderDane, nazwa, czasMax(tr));
      if ~isempty(b)
        R{end+1} = struct('D', b.D, 'kol', kol(i+1,:), 'ls', styles{i+1}, ...
                          'etyk', grupy(g).war{i, 2});
      end
    end
    if isempty(R)
      warning('Trajektoria %d, badanie "%s": brak danych.', tr, grupy(g).id);
      continue
    end

    prefix = sprintf('traj%d_%s', tr, grupy(g).id);
    rysujZestaw(R, prefix, folderWyj, paddingCm, specKaty, specZad, specSym);

    % błąd położenia względem lotu bazowego
    if ~isempty(ref) && numel(R) >= 2
      Re = {};
      for k = 2:numel(R)
        [e, t] = bladPozycji(ref.D, R{k}.D);
        Re{end+1} = struct('D', [t e], 'kol', R{k}.kol, 'ls', R{k}.ls, 'etyk', R{k}.etyk);
        wyniki(end+1, :) = {tr, grupy(g).id, R{k}.etyk, sqrt(mean(e.^2)), e(end)};
      end
      wykresCzasowy(Re, @(D) D(:,2), 'Błąd położenia [m]', ...
                    fullfile(folderWyj, [prefix '_blad_pozycji.pdf']), 5.5, paddingCm);
    end
  end
end

%% ===================== TABELA BŁĘDÓW =====================
if ~isempty(wyniki)
  fprintf('\n=== Błąd położenia względem lotu bazowego (czul1) ===\n');
  for r = 1:size(wyniki, 1)
    fprintf('traj %d | %-6s | %-22s | RMS = %8.3f m | błąd końcowy = %8.3f m\n', wyniki{r,:});
  end
  fid = fopen(fullfile(folderRaport, 'bledy_pozycji.csv'), 'w');
  fwrite(fid, [239 187 191]);                                  % BOM UTF-8 (Excel)
  fprintf(fid, 'Trajektoria,Badanie,Wariant,RMS_bledu_pozycji_m,Blad_koncowy_m\n');
  for r = 1:size(wyniki, 1)
    fprintf(fid, '%d,%s,%s,%.6f,%.6f\n', wyniki{r,:});
  end
  fclose(fid);
end

fprintf('\nGotowe. PDF-y zapisano w: %s\n', folderWyj);
