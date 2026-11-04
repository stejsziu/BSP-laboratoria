%% LAB 5 - System sterowania samolotu bezzałogowego
%  Generowanie wykresów (po polsku) i eksport do PDF przyciętych do wykresu.
%  Wymagania: MATLAB R2020a lub nowszy (exportgraphics, tiledlayout).
%  Plik zapisz w kodowaniu UTF-8 (polskie znaki w opisach osi).
%
%  Wyniki: ../raport/wykresy (względem położenia tego skryptu)
%
%  Układ kolumn w plikach danych (42 kolumny, 3 ostatnie nieopisane w instrukcji):
%   1 czas | 2-5 sygnały zadane (napęd[ms], lotki, wysokość, kierunek [rad])
%   6-9 sygnały symulowane | 10-12 pozycja x,y,z | 13-15 U,V,W | 16-18 ax,ay,az
%   19-21 Phi,Theta,Psi | 22-24 P,Q,R | 25 alfa | 26 beta | 27-39 pomiary | 40-42 ?

clear; clc; close all;

%% ===================== KONFIGURACJA =====================
skryptDir = fileparts(mfilename('fullpath'));
if isempty(skryptDir), skryptDir = pwd; end

folderDane = fullfile(skryptDir, 'src');                                 % folder z plikami .txt
folderWyj  = fullfile(skryptDir, '..', 'raport', 'wykresy');

czasMax       = [Inf Inf];   % [s] obcięcie danych dla trajektorii 1 i 2 (np. [100 50])
oknoRownowagi = [0 Inf];     % [s] okno uśredniania parametrów równowagi (lot swobodny)
paddingPkt    = 2;           % [pt] margines wokół wykresu w PDF

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
[~, info] = fileattrib(folderWyj);  folderWyj = info.Name;   % ścieżka bezwzględna
folderRaport = fileparts(folderWyj);

% definicje paneli: {funkcja liczaca dane z macierzy D, opis osi Y}
specKaty = {
    @(D) rad2deg(D(:,19)),         'Przechylenie \Phi [^\circ]'
    @(D) rad2deg(D(:,20)),         'Pochylenie \Theta [^\circ]'
    @(D) rad2deg(unwrap(D(:,21))), 'Odchylenie \Psi [^\circ]'};
specZad = {
    @(D) D(:,2),          'Napęd [ms]'
    @(D) rad2deg(D(:,3)), 'Lotki [^\circ]'
    @(D) rad2deg(D(:,4)), 'Ster wysokości [^\circ]'
    @(D) rad2deg(D(:,5)), 'Ster kierunku [^\circ]'};
specSym = {
    @(D) D(:,6),          'Napęd [ms]'
    @(D) rad2deg(D(:,7)), 'Lotki [^\circ]'
    @(D) rad2deg(D(:,8)), 'Ster wysokości [^\circ]'
    @(D) rad2deg(D(:,9)), 'Ster kierunku [^\circ]'};
specRown = {
    @(D) sqrt(D(:,13).^2 + D(:,14).^2 + D(:,15).^2), 'Prędkość V [m/s]'
    @(D) rad2deg(D(:,25)),                           'Kąt natarcia \alpha [^\circ]'
    @(D) rad2deg(D(:,8)),                            'Ster wysokości [^\circ]'};

%% ===================== 1. LOT SWOBODNY =====================
sw = wczytajBieg(folderDane, '2_lot_swobodny', Inf);
if ~isempty(sw)
    R = {struct('D', sw.D, 'kol', kol(1,:), 'ls', '-', 'etyk', 'lot swobodny')};
    rysujZestaw(R, 'lot_swobodny', folderWyj, paddingPkt, specKaty, specZad, specSym);
    panele(R, specRown, fullfile(folderWyj, 'lot_swobodny_rownowaga.pdf'), paddingPkt);

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
            R{end+1} = struct('D', ref.D, 'kol', kol(1,:), 'ls', styles{1}, 'etyk', grupy(g).baza); %#ok<SAGROW>
        end
        for i = 1:size(grupy(g).war, 1)
            w = grupy(g).war{i, 1};
            if startsWith(w, 'czul')
                nazwa = sprintf('2_traj%d_%s', tr, w);
            else
                nazwa = sprintf('2_traj%d_czul1_%s', tr, w);
            end
            b = wczytajBieg(folderDane, nazwa, czasMax(tr));
            if ~isempty(b)
                R{end+1} = struct('D', b.D, 'kol', kol(i+1,:), 'ls', styles{i+1}, ...
                                  'etyk', grupy(g).war{i, 2}); %#ok<SAGROW>
            end
        end
        if isempty(R)
            warning('Trajektoria %d, badanie "%s": brak danych.', tr, grupy(g).id);
            continue
        end

        prefix = sprintf('traj%d_%s', tr, grupy(g).id);
        rysujZestaw(R, prefix, folderWyj, paddingPkt, specKaty, specZad, specSym);

        % błąd położenia względem lotu bazowego
        if ~isempty(ref) && numel(R) >= 2
            Re = {};
            for k = 2:numel(R)
                [e, t] = bladPozycji(ref.D, R{k}.D);
                Re{end+1} = struct('D', [t e], 'kol', R{k}.kol, 'ls', R{k}.ls, ...
                                   'etyk', R{k}.etyk); %#ok<SAGROW>
                wyniki(end+1, :) = {tr, grupy(g).id, R{k}.etyk, sqrt(mean(e.^2)), e(end)}; %#ok<SAGROW>
            end
            wykresCzasowy(Re, @(D) D(:,2), 'Błąd położenia [m]', ...
                fullfile(folderWyj, [prefix '_blad_pozycji.pdf']), paddingPkt, 6.5);
        end
    end
end

%% ===================== TABELA BŁĘDÓW =====================
if ~isempty(wyniki)
    T = cell2table(wyniki, 'VariableNames', ...
        {'Trajektoria', 'Badanie', 'Wariant', 'RMS_bledu_pozycji_m', 'Blad_koncowy_m'});
    fprintf('\n=== Błąd położenia względem lotu bazowego (czul1) ===\n');
    for r = 1:size(wyniki, 1)
        fprintf('traj %d | %-6s | %-22s | RMS = %8.3f m | błąd końcowy = %8.3f m\n', wyniki{r,:});
    end
    writetable(T, fullfile(folderRaport, 'bledy_pozycji.csv'), 'Encoding', 'UTF-8');
end

fprintf('\nGotowe. PDF-y zapisano w: %s\n', folderWyj);


%% ===================== FUNKCJE LOKALNE =====================

function rysujZestaw(R, prefix, folderWyj, pad, specKaty, specZad, specSym)
    % trajektoria w płaszczyźnie xy (y poziomo, x pionowo)
    [f, ax] = nowaFig(14, 10);
    for k = 1:numel(R)
        D = R{k}.D;
        plot(ax, D(:,11), D(:,10), R{k}.ls, 'Color', R{k}.kol, 'LineWidth', 1.1);
    end
    axis(ax, 'equal');
    xlabel(ax, 'Położenie y [m]');  ylabel(ax, 'Położenie x [m]');
    dodajLegende(ax, R);
    zapisz(ax, f, fullfile(folderWyj, [prefix '_trajektoria_xy.pdf']), pad);

    % wysokość (h = -z)
    wykresCzasowy(R, @(D) -D(:,12), 'Wysokość [m]', ...
        fullfile(folderWyj, [prefix '_wysokosc.pdf']), pad, 6.5);

    % kąty orientacji, sygnały zadane i symulowane
    panele(R, specKaty, fullfile(folderWyj, [prefix '_katy.pdf']),            pad);
    panele(R, specZad,  fullfile(folderWyj, [prefix '_sterowanie_zadane.pdf']), pad);
    panele(R, specSym,  fullfile(folderWyj, [prefix '_sterowanie_symulowane.pdf']), pad);
end

function wykresCzasowy(R, fy, ylab, plik, pad, wys)
    [f, ax] = nowaFig(14, wys);
    for k = 1:numel(R)
        D = R{k}.D;
        plot(ax, D(:,1), fy(D), R{k}.ls, 'Color', R{k}.kol, 'LineWidth', 1.1);
    end
    xlabel(ax, 'Czas [s]');  ylabel(ax, ylab);
    xlim(ax, [0 max(cellfun(@(r) r.D(end,1), R))]);
    dodajLegende(ax, R);
    zapisz(ax, f, plik, pad);
end

function panele(R, spec, plik, pad)
    m = size(spec, 1);
    f = figure('Visible', 'off', 'Units', 'centimeters', ...
        'Position', [2 2 15 3.4*m + 1.2], 'Color', 'w');
    tl = tiledlayout(f, m, 1, 'TileSpacing', 'compact', 'Padding', 'tight');
    tmax = max(cellfun(@(r) r.D(end,1), R));
    ax1 = [];
    for p = 1:m
        ax = nexttile(tl);
        hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); ax.FontSize = 9;
        for k = 1:numel(R)
            D = R{k}.D;
            plot(ax, D(:,1), spec{p,1}(D), R{k}.ls, 'Color', R{k}.kol, 'LineWidth', 1.1);
        end
        ylabel(ax, spec{p,2});
        xlim(ax, [0 tmax]);
        if p < m, ax.XTickLabel = {}; else, xlabel(ax, 'Czas [s]'); end
        if p == 1, ax1 = ax; end
    end
    if numel(R) > 1
        lg = legend(ax1, cellfun(@(r) r.etyk, R, 'UniformOutput', false), ...
            'FontSize', 8, 'Orientation', 'horizontal');
        lg.Layout.Tile = 'north';
    end
    zapisz(f, f, plik, pad);
end

function dodajLegende(ax, R)
    if numel(R) > 1
        legend(ax, cellfun(@(r) r.etyk, R, 'UniformOutput', false), ...
            'Location', 'best', 'FontSize', 8);
    end
end

function [f, ax] = nowaFig(w, h)
    f  = figure('Visible', 'off', 'Units', 'centimeters', ...
        'Position', [2 2 w h], 'Color', 'w');
    ax = axes(f);
    hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); ax.FontSize = 9;
end

function zapisz(obj, f, plik, pad)
    % obj = axes (przycięcie do samego wykresu z opisami) lub figure (panele)
    drawnow;
    try
        exportgraphics(obj, plik, 'ContentType', 'vector', 'Padding', pad);
    catch
        try
            exportgraphics(obj, plik, 'ContentType', 'vector');
        catch
            f.Units = 'centimeters';  p = f.Position;
            f.PaperUnits = 'centimeters';  f.PaperSize = p(3:4);
            f.PaperPosition = [0 0 p(3:4)];
            print(f, plik, '-dpdf', '-painters');
        end
    end
    close(f);
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

function plik = znajdzPlik(folder, baza)
    % obsługa nazw typu: x.txt, x.txt.txt oraz "2traj2" zamiast "2_traj2"
    bazy = unique({baza, strrep(baza, '2_traj', '2traj')}, 'stable');
    plik = '';
    for b = 1:numel(bazy)
        for ext = {'.txt', '.txt.txt'}
            p = fullfile(folder, [bazy{b} ext{1}]);
            if exist(p, 'file') == 2, plik = p; return; end
        end
    end
end

function D = wczytajDane(plik)
    % Pomija linie tekstowe (INFO, TIME, ...) i czyta tylko wiersze numeryczne
    txt   = fileread(plik);
    linie = regexp(txt, '\r?\n', 'split');
    ok    = ~cellfun('isempty', regexp(linie, '^\s*[-+]?\d*\.?\d+([eE][-+]?\d+)?\t', 'once'));
    C     = cellfun(@(s) sscanf(s, '%f')', linie(ok), 'UniformOutput', false);
    n     = cellfun(@numel, C);
    if isempty(n), error('Brak danych liczbowych w pliku %s', plik); end
    C = C(n == mode(n));                       % odrzuć urwane wiersze
    D = vertcat(C{:});
    k = find(diff(D(:,1)) <= 0, 1, 'last');    % restart zapisu w trakcie pliku
    if ~isempty(k)
        warning('%s: czas się cofa - użyto ostatniego odcinka zapisu.', plik);
        D = D(k+1:end, :);
    end
end
