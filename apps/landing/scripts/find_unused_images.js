const fs = require('fs');
const path = require('path');

const publicDir = 'c:/appdefinitiva/apps/landing/public';
const searchDir = 'c:/appdefinitiva/apps/landing';
const extensionsToSearch = ['.tsx', '.ts', '.jsx', '.js', '.css', '.json'];

function getAllFiles(dir, filter) {
    let results = [];
    const list = fs.readdirSync(dir);
    list.forEach(file => {
        file = path.join(dir, file);
        const stat = fs.statSync(file);
        if (stat && stat.isDirectory()) {
            if (!file.includes('node_modules') && !file.includes('.next') && !file.includes('public')) {
                results = results.concat(getAllFiles(file, filter));
            }
        } else {
            if (filter.includes(path.extname(file))) {
                results.push(file);
            }
        }
    });
    return results;
}

function getAllImages(dir) {
    let results = [];
    const list = fs.readdirSync(dir);
    list.forEach(file => {
        const fullPath = path.join(dir, file);
        const stat = fs.statSync(fullPath);
        if (stat && stat.isDirectory()) {
            results = results.concat(getAllImages(fullPath));
        } else {
            if (fullPath.match(/\.(png|jpg|jpeg|webp|svg)$/i)) {
                results.push(fullPath);
            }
        }
    });
    return results;
}

const allCodeFiles = getAllFiles(searchDir, extensionsToSearch);
const allImages = getAllImages(publicDir);
const unusedImages = [];

console.log(`Searching in ${allCodeFiles.length} code files for ${allImages.length} images...`);

// Load all code content once to be fast
const codeContents = allCodeFiles.map(f => fs.readFileSync(f, 'utf8'));

allImages.forEach(imagePath => {
    const filename = path.basename(imagePath);
    let isUsed = false;
    
    for (const content of codeContents) {
        if (content.includes(filename)) {
            isUsed = true;
            break;
        }
    }
    
    if (!isUsed) {
        unusedImages.push(imagePath);
    }
});

console.log('\n--- UNUSED IMAGES ---');
unusedImages.forEach(img => console.log(img));
console.log(`\nTotal: ${unusedImages.length} unused images.`);

// Delete them if user wants, but for now just list
// unusedImages.forEach(img => fs.unlinkSync(img));
