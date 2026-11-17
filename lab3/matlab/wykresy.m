close all; %clear all;
g = 9.81;

a.x = readmatrix("src\Gr2_gx_osx.txt", "Range","B1:D1690");
a.y = readmatrix("src\Gr2_gx_osy.txt", "Range","B1:D2540");
a.z = readmatrix("src\Gr2_gx_osz.txt", "Range","B1:D1650");
a.z(1084, 2) = 2.29;
gir.x = readmatrix("chujniki\gir_x.csv", "Range","E1:E1700");
gir.czasx = readmatrix("chujniki\gir_x.csv", "Range","A1:A1700");
gir.y = readmatrix("chujniki\gir_y.csv", "Range","F1:F1990");
gir.czasy = readmatrix("chujniki\gir_y.csv", "Range","A1:A1990");
gir.z = readmatrix("chujniki\gir_z.csv", "Range","G1:G1810");
gir.czasz = readmatrix("chujniki\gir_z.csv", "Range","A1:A1810");
dowolny = readmatrix("chujniki\gir_dowolny.csv", "Range", "B1:G4600");
czas = readmatrix("chujniki\gir_dowolny.csv", "Range", "A1:A4600");

% Detect change points (edges between flat regions)
idx.xy = findchangepts(a.x(:,2), 'Statistic','mean', 'MaxNumChanges',6);
idx.xz = findchangepts(a.x(:,3), 'Statistic','mean', 'MaxNumChanges',6);
idx.yx = findchangepts(a.y(:,1), 'Statistic','mean', 'MaxNumChanges',6);
idx.yz = findchangepts(a.y(:,3), 'Statistic','mean', 'MaxNumChanges',6);
idx.zx = findchangepts(a.z(:,1), 'Statistic','mean', 'MaxNumChanges',6);
idx.zy = findchangepts(a.z(:,2), 'Statistic','mean', 'MaxNumChanges',6);

% Add start and end
idx.xy = [1; idx.xy; length(a.x(:,2))];
idx.xz = [1; idx.xz; length(a.x(:,3))];
idx.yx = [1; idx.yx; length(a.y(:,1))];
idx.yz = [1; idx.yz; length(a.y(:,3))];
idx.zx = [1; idx.zx; length(a.z(:,1))];
idx.zy = [1; idx.zy; length(a.z(:,2))];

% Compute averages
means.xy = zeros(length(idx.xy)-1,1);
means.xz = zeros(length(idx.xz)-1,1);
means.yx = zeros(length(idx.yx)-1,1);
means.yz = zeros(length(idx.yz)-1,1);
means.zx = zeros(length(idx.zx)-1,1);
means.zy = zeros(length(idx.zy)-1,1);

for k = 1:length(idx.xy)-1
    segment.xy = a.x(idx.xy(k):idx.xy(k+1), 2);
    means.xy(k) = mean(segment.xy);
    segment.xz = a.x(idx.xz(k):idx.xz(k+1), 3);
    means.xz(k) = mean(segment.xz);
end
for k = 1:length(idx.yx)-1
    segment.yx = a.y(idx.yx(k):idx.yx(k+1), 1);
    means.yx(k) = mean(segment.yx);
    segment.yz = a.y(idx.yz(k):idx.yz(k+1), 3);
    means.yz(k) = mean(segment.yz);
end
for k = 1:length(idx.zx)-1
    segment.zx = a.z(idx.zx(k):idx.zx(k+1), 1);
    means.zx(k) = mean(segment.zx);
    segment.zy = a.z(idx.zy(k):idx.zy(k+1), 2);
    means.zy(k) = mean(segment.zy);
end

[id.xy, centers.xy] = kmeans(means.xy, 3);
[id.xz, centers.xz] = kmeans(means.xz, 3);
[id.yx, centers.yx] = kmeans(means.yx, 3);
[id.yz, centers.yz] = kmeans(means.yz, 3);
[id.zx, centers.zx] = kmeans(means.zx, 3);
[id.zy, centers.zy] = kmeans(means.zy, 3);

[sorted_centers.xy, order.xy] = sort(centers.xy);
[sorted_centers.xz, order.xz] = sort(centers.xz);
[sorted_centers.yx, order.yx] = sort(centers.yx);
[sorted_centers.yz, order.yz] = sort(centers.yz);
[sorted_centers.zx, order.zx] = sort(centers.zx);
[sorted_centers.zy, order.zy] = sort(centers.zy);

alfa.xy = (max(centers.xy - min(centers.xy))) / (2 * g);
alfa.xz = (max(centers.xz - min(centers.xz))) / (2 * g);
alfa.yx = (max(centers.yx - min(centers.yx))) / (2 * g);
alfa.yz = (max(centers.yz - min(centers.yz))) / (2 * g);
alfa.zx = (max(centers.zx - min(centers.zx))) / (2 * g);
alfa.zy = (max(centers.zy - min(centers.zy))) / (2 * g);

alfa.x = (alfa.yx + alfa.zx) / 2;
alfa.y = (alfa.xy + alfa.zy) / 2;
alfa.z = (alfa.yz + alfa.xz) / 2;

b.x = mean(a.x(:,1));
b.y = mean(a.y(:,2));
b.z = mean(a.z(:,3));

acc.x = (dowolny(:,1) - b.x) / alfa.x;
acc.y = (dowolny(:,2) - b.y) / alfa.y;
acc.z = (dowolny(:,3) - b.z) / alfa.z;

%%
figure;
hold on; grid on;
plot(czas, acc.x);
plot(czas, acc.y);
plot(czas, acc.z);
legend("a_x", "a_y", "a_z");

%% giroskopy

figure;
plot(gir.czasx, gir.x);
figure;
plot(gir.czasy, gir.y);
figure;
plot(gir.czasz, gir.z);

t.x = [1.29, 3.39, 4.23, 6.66, 9.52, 12.06, 13.33, 15.35];
t.y = [1.35, 3.48, 4.19, 7.32, 10.51, 13.31, 14.13, 16.99];
t.z = [1.42, 4.09, 5.05, 7.5, 8.64, 11.79, 12.85, 15.71];

U0.x = mean(gir.x(1:100,1));
U0.y = mean(gir.y(1:100,1));
U0.z = mean(gir.z(1:100,1));

U.x = gir.x - U0.x;
U.y = gir.y - U0.y;
U.z = gir.z - U0.z;

for i=1:8
    index.x(i) = find(gir.czasx > t.x(i), 1, "first");
    index.y(i) = find(gir.czasy > t.y(i), 1, "first");
    index.z(i) = find(gir.czasz > t.z(i), 1, "first");
end

for i=1:4
    integral_val.x(i) = trapz(gir.czasx(index.x(2*i-1):index.x(2*i)), U.x(index.x(2*i-1):index.x(2*i)));
    integral_val.y(i) = trapz(gir.czasy(index.y(2*i-1):index.y(2*i)), U.y(index.y(2*i-1):index.y(2*i)));
    integral_val.z(i) = trapz(gir.czasz(index.z(2*i-1):index.z(2*i)), U.z(index.z(2*i-1):index.z(2*i)));
end

kw.x = mean(90 ./ integral_val.x);
kw.y = mean(90 ./ integral_val.y);
kw.z = mean(90 ./ integral_val.z);

gir.dowolnyx = (dowolny(:,4) - U0.x) * kw.x;
gir.dowolnyy = (dowolny(:,5) - U0.y) * kw.y;
gir.dowolnyz = (dowolny(:,6) - U0.z) * kw.z;

%% r-nia kinematycze

macierz = @(phi, teta, psi) [1 sind(phi)*tand(teta) cosd(phi)*tand(teta);
                             0 cosd(phi) -sind(phi);
                             0 sind(phi)/cosd(teta) cosd(phi)/cosd(teta)];

phi = zeros(length(czas),1);
theta = zeros(length(czas),1);
psi = zeros(length(czas),1);
dt = 1/200;

for i=1:length(czas) - 1
    T = macierz(phi(i), theta(i), psi(i));
    OMMega = [gir.dowolnyx(i) gir.dowolnyy(i) gir.dowolnyz(i)]';
    euler_d = T * OMMega;

    phi(i+1) = phi(i) + euler_d(1) * dt;
    theta(i+1) = theta(i) + euler_d(2) * dt;
    psi(i+1) = psi(i) + euler_d(3) * dt;
end

figure;
hold on, grid on;
plot(czas, phi);
plot(czas, theta);
plot(czas,psi);
legend("przechylenie", "pochylenie", "odchylenie");
title("r-nia kinematyczne");

%% kwateriniony

phi0 = 0; theta0 = 0; psi0 = 0;
phik = phi0; thetak = theta0; psik = psi0;

qa0 = cosd(psi0/2)*cosd(theta0/2)*cosd(phi0/2)+sind(psi0/2)*sind(theta0/2)*sind(phi0/2);
qa1 = cosd(psi0/2)*cosd(theta0/2)*sind(phi0/2)-sind(psi0/2)*sind(theta0/2)*cosd(phi0/2);
qa2 = cosd(psi0/2)*sind(theta0/2)*cosd(phi0/2)+sind(psi0/2)*cosd(theta0/2)*sind(phi0/2);
qa3 = sind(psi0/2)*cosd(theta0/2)*cosd(phi0/2)-cosd(psi0/2)*sind(theta0/2)*sind(phi0/2);

for i=2:length(czas)
    w = sqrt(gir.dowolnyx(i)^2 + gir.dowolnyy(i)^2 + gir.dowolnyz(i)^2);
    thetab = w * dt;

    qb0 = cosd(thetab/2);
    qb1 = sind(thetab/2)*gir.dowolnyx(i)/w;
    qb2 = sind(thetab/2)*gir.dowolnyy(i)/w;
    qb3 = sind(thetab/2)*gir.dowolnyz(i)/w;

    %q0 = qb0*qa0 - qb1*qa1 - qb2*qa2 - qb3*qa3;
    %q1 = qb0*qa1 - qb1*qa0 - qb2*qa3 - qb3*qa2;
    %q2 = qb0*qa2 - qb1*qa3 - qb2*qa0 - qb3*qa1;
    %q3 = qb0*qa3 - qb1*qa2 - qb2*qa1 - qb3*qa0;

    q0 = qa0*qb0 - qa1*qb1 - qa2*qb2 - qa3*qb3;
    q1 = qa0*qb1 + qa1*qb0 + qa2*qb3 - qa3*qb2;
    q2 = qa0*qb2 - qa1*qb3 + qa2*qb0 + qa3*qb1;
    q3 = qa0*qb3 + qa1*qb2 - qa2*qb1 + qa3*qb0;

    norm_q = sqrt(q0^2 + q1^2 + q2^2 + q3^2);

    q0 = q0 / norm_q;
    q1 = q1 / norm_q;
    q2 = q2 / norm_q;
    q3 = q3 / norm_q;

    thetak(i) = asind(-2*(q1*q3-q0*q2));
    phik(i) = atan2d(2*(q2*q3 + q0*q1), 1 - 2*(q1^2 + q2^2));
    psik(i) = atan2d(2*(q1*q2 + q0*q3), 1 - 2*(q2^2 + q3^2));

    qa0 = q0;
    qa1 = q1;
    qa2 = q2;
    qa3 = q3;
end

psik_unwrapped = unwrap(deg2rad(psik));
psik_unwrapped = rad2deg(psik_unwrapped);

phik_unwrapped = unwrap(deg2rad(phik));
phik_unwrapped = rad2deg(phik_unwrapped);

figure;
hold on, grid on;
plot(czas, phik_unwrapped);
plot(czas, thetak);
plot(czas, psik_unwrapped);
legend("przechylenie", "pochylenie", "odchylenie");
title("rachunek kwaternionowy");

%% wykresy

% wymiary renderu pdf
width = 15;
height = 8;

% ustawienia siatki
gridTransparency = .3;
gridColor = [0.5, 0.5, 0.5];

% spis kolorow
szary = '#000072';
granatowy = '#2239a1';
czarny = '#121212';
fioletowy = '#4b047c';
zielony = '#1c600f';
bordowy = '#680404';

col_a_x = '#2F4B7C';
col_a_y = '#2A9D8F';
col_a_z = '#F4A261';

col_gir_x = '#6A4C93';
col_gir_y = '#8DA9C4';
col_gir_z = '#F28482';

RLC_fit_color = granatowy;
RC_fit_color = bordowy;
otherColor = czarny;

% grubosci kresek
main_plotWidth = 2;
other_plotWidth = 1.25;

% czcionki
rozmiarCzcionkiMin = 12; % normal text
rozmiarCzcionkiMid = 13; % subtitle
rozmiarCzcionkiBig = 15; % title

%% przyspieszenia - raw

wykres = figure;
    set(gcf, 'Name', 'Ruch dowolny', 'NumberTitle', 'off', 'Units', 'centimeters', 'Position', [10, 10, width, height]);
    set(gcf, 'PaperUnits', 'centimeters', 'PaperSize', [width, height]); % [width, height]
    set(gcf, 'PaperPosition', [0, 0, width, height]); % [left, bottom, width, height]
    set(gca, 'FontSize', rozmiarCzcionkiMin);

hold on;  

plot(czas, dowolny(:,1), 'LineWidth', other_plotWidth, 'Color', col_a_x);
plot(czas, dowolny(:,2), 'LineWidth', other_plotWidth, 'Color', col_a_y);
plot(czas, dowolny(:,3), 'LineWidth', other_plotWidth, 'Color', col_a_z);

title('Ruch dowolny - akcelerometry', 'FontSize', rozmiarCzcionkiBig, 'FontWeight', 'bold');
subtitle('dane nieobrobione', 'FontSize', rozmiarCzcionkiMid);
legend('a_x', 'a_y', 'a_z', 'Location', 'northwest');
    xlabel (['time ', '[s]']); ylabel(['voltage', '[V]']);
    xlim([min(czas) - 1, max(czas) + 1]);
    grid on;
        ax = gca;
        ax.GridColor = gridColor; 
        ax.GridAlpha = gridTransparency;

print(gcf, 'przyspieszenia_gole dane(nsfw)', '-dpdf', '-r300', '-vector');

%% giroskopy - raw

wykres = figure;
    set(gcf, 'Name', 'Ruch dowolny', 'NumberTitle', 'off', 'Units', 'centimeters', 'Position', [10, 10, width, height]);
    set(gcf, 'PaperUnits', 'centimeters', 'PaperSize', [width, height]); % [width, height]
    set(gcf, 'PaperPosition', [0, 0, width, height]); % [left, bottom, width, height]
    set(gca, 'FontSize', rozmiarCzcionkiMin);

hold on;  

plot(czas, dowolny(:,4), 'LineWidth', other_plotWidth, 'Color', col_gir_x);
plot(czas, dowolny(:,5), 'LineWidth', other_plotWidth, 'Color', col_gir_y);
plot(czas, dowolny(:,6), 'LineWidth', other_plotWidth, 'Color', col_gir_z);

title('Ruch dowolny - giroskopy', 'FontSize', rozmiarCzcionkiBig, 'FontWeight', 'bold');
subtitle('dane nieobrobione', 'FontSize', rozmiarCzcionkiMid);
legend('\omega_x', '\omega_y', '\omega_z', 'Location', 'northeast');
    xlabel (['time ', '[s]']); ylabel(['voltage', '[V]']);
    xlim([min(czas) - 1, max(czas) + 1]);
    grid on;
        ax = gca;
        ax.GridColor = gridColor; 
        ax.GridAlpha = gridTransparency;

print(gcf, 'giroskopy_gole dane(nsfw)', '-dpdf', '-r300', '-vector');

%% giroskopy - kinematyka

wykres = figure;
    set(gcf, 'Name', 'Ruch dowolny', 'NumberTitle', 'off', 'Units', 'centimeters', 'Position', [10, 10, width, height]);
    set(gcf, 'PaperUnits', 'centimeters', 'PaperSize', [width, height]); % [width, height]
    set(gcf, 'PaperPosition', [0, 0, width, height]); % [left, bottom, width, height]
    set(gca, 'FontSize', rozmiarCzcionkiMin);

hold on; 

plot(czas, phi, 'LineWidth', other_plotWidth, 'Color', col_gir_x);
plot(czas, theta, 'LineWidth', other_plotWidth, 'Color', col_gir_y);
plot(czas, psi, 'LineWidth', other_plotWidth, 'Color', col_gir_z);

title('Ruch dowolny - giroskopy', 'FontSize', rozmiarCzcionkiBig, 'FontWeight', 'bold');
subtitle('r-nia kinematyki', 'FontSize', rozmiarCzcionkiMid);
%legend('przechylenie', 'pochylenie', 'odchylenie', 'Location', 'northeast');
legend('\Phi', '\Theta', '\Psi', 'Location', 'northeast');
    xlabel (['time ', '[s]']); ylabel(['angle', '[deg]']);
    xlim([min(czas) - 1, max(czas) + 1]);
    grid on;
        ax = gca;
        ax.GridColor = gridColor; 
        ax.GridAlpha = gridTransparency;

print(gcf, 'giroskopy_kinematyka', '-dpdf', '-r300', '-vector');

%% giroskopy - kwaterniony

wykres = figure;
    set(gcf, 'Name', 'Ruch dowolny', 'NumberTitle', 'off', 'Units', 'centimeters', 'Position', [10, 10, width, height]);
    set(gcf, 'PaperUnits', 'centimeters', 'PaperSize', [width, height]); % [width, height]
    set(gcf, 'PaperPosition', [0, 0, width, height]); % [left, bottom, width, height]
    set(gca, 'FontSize', rozmiarCzcionkiMin);

hold on; 

plot(czas, phik_unwrapped, 'LineWidth', other_plotWidth, 'Color', col_gir_x);
plot(czas, thetak, 'LineWidth', other_plotWidth, 'Color', col_gir_y);
plot(czas, psik_unwrapped, 'LineWidth', other_plotWidth, 'Color', col_gir_z);

title('Ruch dowolny - giroskopy', 'FontSize', rozmiarCzcionkiBig, 'FontWeight', 'bold');
subtitle('rachunek kwaternionowy', 'FontSize', rozmiarCzcionkiMid);
%legend('przechylenie', 'pochylenie', 'odchylenie', 'Location', 'northeast');
legend('\Phi', '\Theta', '\Psi', 'Location', 'northeast');
    xlabel (['time ', '[s]']); ylabel(['angle', '[deg]']);
    xlim([min(czas) - 1, max(czas) + 1]);
    grid on;
        ax = gca;
        ax.GridColor = gridColor; 
        ax.GridAlpha = gridTransparency;

print(gcf, 'giroskopy_kwaterniony', '-dpdf', '-r300', '-vector');

%% akcelerometry

wykres = figure;
    set(gcf, 'Name', 'Ruch dowolny', 'NumberTitle', 'off', 'Units', 'centimeters', 'Position', [10, 10, width, height]);
    set(gcf, 'PaperUnits', 'centimeters', 'PaperSize', [width, height]); % [width, height]
    set(gcf, 'PaperPosition', [0, 0, width, height]); % [left, bottom, width, height]
    set(gca, 'FontSize', rozmiarCzcionkiMin);

hold on; 

plot(czas, acc.x, 'LineWidth', other_plotWidth, 'Color', col_a_x);
plot(czas, acc.y, 'LineWidth', other_plotWidth, 'Color', col_a_y);
plot(czas, acc.z, 'LineWidth', other_plotWidth, 'Color', col_a_z);

title('Ruch dowolny - akcelerometry', 'FontSize', rozmiarCzcionkiBig, 'FontWeight', 'bold');
subtitle('dane przetworzone', 'FontSize', rozmiarCzcionkiMid);
legend('a_x', 'a_y', 'a_z', 'Location', 'northeast');
    xlabel (['time ', '[s]']); ylabel(['acceleration', '[m/s^2]']);
    xlim([min(czas) - 1, max(czas) + 1]);
    grid on;
        ax = gca;
        ax.GridColor = gridColor; 
        ax.GridAlpha = gridTransparency;

print(gcf, 'przyspieszenia', '-dpdf', '-r300', '-vector');