function erdpdf(entity)
assert( strncmpi(computer,'mac',3), 'Has not been tested on a non-Mac')

erd(entity)

set(gcf,'PaperUnits','inches','PaperPosition',[0 0 11 8],'PaperSize',[11 8])
print('-dpdf', './temp_erd')

if ~strncmpi(computer, 'MAC', 3)
    disp 'Saved temp erd'
else
    % on a mac, open the PDF and erase the file
    system('open ./temp_erd.pdf; rm ./temp_erd.pdf');
end
close(gcf)