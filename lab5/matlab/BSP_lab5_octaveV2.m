%% LAB 5 - System sterowania samolotu bezzałogowego  (wersja dla GNU Octave)
%  Generowanie zwartego zestawu wykresów (subpoty) i eksport do PDF.
%  Dane:  ./src   (obok skryptu)      Wyniki: ../raport/wykresy
%  Plik zapisz w UTF-8.

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
  C = C(n == mode(n));                 % odrzuć urwane wiersze
  D = vertcat(C{:});
  k = find(diff(D(:,1)) <= 0, 1, 'last');     % restart zapisu w trakcie pliku
  if ~isempty(k)
    warning('%s: czas się cofa - użyto ostatniego odcinka zapisu.', plik);
    D = D(k+1:end, :);
  end
end

function plik = znajdzPlik(folder, baza)
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
  tmax = min(Dref(end,1), Dbieg(end,1));
  mk   = Dref(:,1) <= tmax;
  t    = Dref(mk, 1);
  [tu, iu] = unique(Dbieg(:,1));
  P    = interp1(tu, Dbieg(iu, 10:12), t, 'linear');
  e    = sqrt(sum((P - Dref(mk, 10:12)).^2, 2));
end

function f = nowaFig()
  % Rozmiar dostosowany pod format kompaktowy (A4 / raport dwukolumnowy lub zwarty)
  f = figure('Visible', 'off', 'Units', 'centimeters', 'Position', [2 2 18 22], ...
             'Color', 'w');
end

function zapiszKompaktowo(f, plik, padCm)
  set(f, 'PaperUnits', 'centimeters');
  % Pobierz aktualny rozmiar okna i ustaw na papierze
  pos = get(f, 'Position');
  set(f, 'PaperSize', pos(3:4));
  set(f, 'PaperPosition', [0 0 pos(3:4)]);
  drawnow;
  print(f, plik, '-dpdf', sprintf('-r300'));
  close(f);
end

function e = etykiety(R)
  if numel(R) > 1
    e = cell(1, numel(R));
    for k = 1:numel(R), e{k} = R{k}.etyk; end
  else
    e = {};
  end
end

function rysujZestawKompaktowy(R, Re, prefix, folderWyj, pad)
  % Tworzy jedną zwartą figurę z 4 kluczowymi subplotami:
  % 1. Trajektoria XY (góra po lewej)
  % 2. Wysokość (góra po prawej)
  % 3. Kąty (Przechylenie i Pochylenie - środek)
  % 4. Błąd położenia względem referencji (dół)

  f = nowaFig();

  r2d = @(x) x * 180 / pi;
  tmax = 0;
  for k = 1:numel(R), tmax = max(tmax, R{k}.D(end,1)); end

  % --- Podplot 1: Trajektoria XY ---
  subplot(3, 2, 1);
  hold on; grid on;
  for k = 1:numel(R)
    D = R{k}.D;
    plot(D(:,11), D(:,10), R{k}.ls, 'Color', R{k}.kol, 'LineWidth', 1.0);
  end
  xlabel('Poł. Y [m]'); ylabel('Poł. X [m]');
  title('Trajektoria XY', 'FontSize', 9);
  axis equal;

  % --- Podplot 2: Wysokość ---
  subplot(3, 2, 2);
  hold on; grid on;
  for k = 1:numel(R)
    D = R{k}.D;
    plot(D(:,1), -D(:,12), R{k}.ls, 'Color', R{k}.kol, 'LineWidth', 1.0);
  end
  xlabel('Czas [s]'); ylabel('Wysokość [m]');
  xlim([0 tmax]);
  title('Wysokość lotu', 'FontSize', 9);

  % --- Podplot 3: Kąt Przechylenia (\Phi) ---
  subplot(3, 2, 3);
  hold on; grid on;
  for k = 1:numel(R)
    D = R{k}.D;
    plot(D(:,1), r2d(D(:,19)), R{k}.ls, 'Color', R{k}.kol, 'LineWidth', 1.0);
  end
  xlabel('Czas [s]'); ylabel('\Phi [^\circ]');
  xlim([0 tmax]);
  title('Przechylenie', 'FontSize', 9);

  % --- Podplot 4: Kąt Pochylenia (\Theta) ---
  subplot(3, 2, 4);
  hold on; grid on;
  for k = 1:numel(R)
    D = R{k}.D;
    plot(D(:,1), r2d(D(:,20)), R{k}.ls, 'Color', R{k}.kol, 'LineWidth', 1.0);
  end
  xlabel('Czas [s]'); ylabel('\Theta [^\circ]');
  xlim([0 tmax]);
  title('Pochylenie', 'FontSize', 9);

  % --- Podplot 5 & 6 (połączone na dole): Błąd położenia ---
  if ~isempty(Re)
    subplot(3, 2, [5 6]);
    hold on; grid on;
    for k = 1:numel(Re)
      D = Re{k}.D;
      plot(D(:,1), D(:,2), Re{k}.ls, 'Color', Re{k}.kol, 'LineWidth', 1.1);
    end
    xlabel('Czas [s]'); ylabel('Błąd [m]');
    xlim([0 tmax]);
    title('Błąd położenia wzgl. bazowego', 'FontSize', 9);

    etyks = etykiety(Re);
    if ~isempty(etyks)
      legend(etyks, 'Location', 'northeast', 'FontSize', 7);
    end
  else
    % Jeśli brak referencji, wrzućmy tam np. sterowanie wysokością
    subplot(3, 2, [5 6]);
    hold on; grid on;
    for k = 1:numel(R)
      D = R{k}.D;
      plot(D(:,1), r2d(D(:,8)), R{k}.ls, 'Color', R{k}.kol, 'LineWidth', 1.0);
    end
    xlabel('Czas [s]'); ylabel('Ster wys. [^\circ]');
    xlim([0 tmax]);
    title('Sterowanie symulowane (Ster wysokości)', 'FontSize', 9);
    etyks = etykiety(R);
    if ~isempty(etyks)
      legend(etyks, 'Location', 'northeast', 'FontSize', 7);
    end
  end

  % Ogólna legenda w prawym górnym rogu pierwszego wykresu lub nad całością
  % (opcjonalnie dla całego zbioru)

  zapiszKompaktowo(f, fullfile(folderWyj, [prefix '_kompaktowy.pdf']), pad);
end

%% ===================== KONFIGURACJA =====================
clear; clc; close all;

skryptDir = fileparts(mfilename('fullpath'));
if isempty(skryptDir), skryptDir = pwd; end

folderDane = fullfile(skryptDir, 'src');
folderWyj  = fullfile(skryptDir, '..', 'raport', 'wykresy');

czasMax       = [Inf Inf];
oknoRownowagi = [0 Inf];
paddingCm     = 0.08;

grupy = struct('id', {}, 'baza', {}, 'war', {});
grupy(1).id = 'serwo'; grupy(1).baza = 'bez serwomechanizmów';
grupy(1).war = {'serwo10', 'prędkość serwa 10'; 'serwo90', 'prędkość serwa 90'};
grupy(2).id = 'luz';   grupy(2).baza = 'bez luzów';
grupy(2).war = {'luz1', 'luz 1%'; 'luz10', 'luz 10%'};
grupy(3).id = 'opoz';  grupy(3).baza = 'bez opóźnienia';
grupy(3).war = {'opoz01', 'opóźnienie 0,1 s'; 'opoz1', 'opóźnienie 1 s'};
grupy(4).id = 'szum';  grupy(4).baza = 'bez szumów';
grupy(4).war = {'szum1', 'moc szumu 1'; 'szum10', 'moc szumu 10'};
grupy(5).id = 'czul';  grupy(5).baza = 'czułość AP = 1';
grupy(5).war = {'czul10', 'czułość AP = 10'};

kol    = [0 0 0; 0 0.447 0.741; 0.850 0.325 0.098; 0.466 0.674 0.188; 0.494 0.184 0.556];
styles = {'-', '--', '-.', ':', '-'};

%% ===================== PRZYGOTOWANIE =====================
if ~exist(folderWyj, 'dir'), mkdir(folderWyj); end
[st, info] = fileattrib(folderWyj);
if st == 1, folderWyj = info.Name; end
folderRaport = fileparts(folderWyj);

r2d = @(x) x * 180 / pi;

%% ===================== 1. LOT SWOBODNY =====================
sw = wczytajBieg(folderDane, '2_lot_swobodny', Inf);
if ~isempty(sw)
  R = {struct('D', sw.D, 'kol', kol(1,:), 'ls', '-', 'etyk', 'lot swobodny')};
  rysujZestawKompaktowy(R, {}, 'lot_swobodny', folderWyj, paddingCm);
end

%% ===================== 2-5. LOTY AUTOMATYCZNE =====================
wyniki = cell(0, 5);

for tr = 1:2
  ref = wczytajBieg(folderDane, sprintf('2_traj%d_czul1', tr), czasMax(tr));

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
    if isempty(R), continue; end

    Re = {};
    if ~isempty(ref) && numel(R) >= 2
      for k = 2:numel(R)
        [e, t] = bladPozycji(ref.D, R{k}.D);
        Re{end+1} = struct('D', [t e], 'kol', R{k}.kol, 'ls', R{k}.ls, 'etyk', R{k}.etyk);
        wyniki(end+1, :) = {tr, grupy(g).id, R{k}.etyk, sqrt(mean(e.^2)), e(end)};
      end
    end

    prefix = sprintf('traj%d_%s', tr, grupy(g).id);
    rysujZestawKompaktowy(R, Re, prefix, folderWyj, paddingCm);
  end
end

%% ===================== TABELA BŁĘDÓW =====================
if ~isempty(wyniki)
  fprintf('\n=== Błąd położenia względem lotu bazowego (czul1) ===\n');
  fid = fopen(fullfile(folderRaport, 'bledy_pozycji.csv'), 'w');
  fwrite(fid, [239 187 191]);
  fprintf(fid, 'Trajektoria,Badanie,Wariant,RMS_bledu_pozycji_m,Blad_koncowy_m\n');
  for r = 1:size(wyniki, 1)
    fprintf(fid, '%d,%s,%s,%.6f,%.6f\n', wyniki{r,:});
  end
  fclose(fid);
end

fprintf('\nGotowe. Zwarte pliki PDF zapisano w: %s\n', folderWyj);
